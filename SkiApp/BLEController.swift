//
//  BLEManager.swift
//  Skisensor2


import Foundation
import CoreBluetooth
import Movesense
import Sentry
import CoreData

struct MovesenseSensor: Hashable {
    let peripheral: CBPeripheral
    let name: String
    var connectionState: ConnectionState
}

struct MovesenseConnection: Hashable {
    let serial: String
    let uuid: UUID
    var bootloaderVersion: String
    var firmwareVersion: String
    var firmwareName: String
    var firmwareManufacturer: String
    var lastMeasurement: Date?
}

struct MovesenseDatapoint: Hashable, Identifiable {
    var id: Double
    let axis: String
    let value: Double
}

enum RecordingState: Int, Codable {
    case Stopped = 0
    case Running = 1
}

public struct SkisensorMeasurement: Codable {
    public let Acc: Array3D
    public let Gyro: Array3D
    public let Magn: Array3D
    public let Timestamp: Int
}

public struct Array3D: Codable {
    public let x: Int16
    public let y: Int16
    public let z: Int16
}

public struct SkisensorRecordingStatus: Codable {
    public let Status: Int
}

enum ConnectionState {
    case Unconnected
    case Connecting
}

enum ScanState {
    case Off
    case On
}

enum SkisensorError: Error {
    case SensorNotFound
}

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}

final class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var moc: NSManagedObjectContext?
    
    @Published var isSwitchedOn = false
    
    @Published var scanState = ScanState.Off
    
    // Sensor in close vicinity, found by a scan but not connected
    @Published var sensors: Dictionary<UUID, MovesenseSensor> = [:]
    
    // Sensor connected to the mobile phone
    @Published var connections: Dictionary<String, MovesenseConnection> = [:]
    
    var bleCentral: CBCentralManager!
    var mds : MDSWrapper!
    var decoder = JSONDecoder()
    
    var sessionEntity: SessionEntity?
    
    var scanTimer: Timer?
    
    override init() {
        super.init()
        mds = MDSWrapper()
        bleCentral = CBCentralManager(delegate: self, queue: nil)

        // Subscribe to sensor connections and disconnections
        mds.doSubscribe(
            "MDS/ConnectedDevices",
            contract: [:],
            response: { (response) in
                if response.statusCode < 300 {
                    print("Subscription successful")
                } else {
                    print("Subscription failed:")
                    print(response.header["Uri"] as! String, response.header["Reason"] as! String)
                }
            },
            onEvent: { (event) in
                do {
                    let decodedEvent = try self.decoder.decode(MovesenseDeviceEvent.self, from: event.bodyData)
                    let serial = decodedEvent.eventBody.serialNumber
                    switch decodedEvent.eventMethod {
                    case .post:
                        self.sensors = self.sensors.filter({ uuid, sensor in
                            return sensor.peripheral.name != "Movesense \(serial)"
                        })
                        print("\(serial) connected")
                        let uuid = decodedEvent.eventBody.connectionInfo?.connectionUuid
                        Task.detached {
                            do {
                                let appInfo = try await self.getAppInfo(serial: serial)
                                let sensorInfo = try await self.getSensorInfo(serial: serial)
                                self.connections[serial] = MovesenseConnection(serial: serial, uuid: uuid!, bootloaderVersion: sensorInfo.swVersion, firmwareVersion: appInfo.version, firmwareName: appInfo.name, firmwareManufacturer: appInfo.company)
                            } catch {
                                print(error)
                                SentrySDK.capture(error: error)
                            }
                        }
                        
                    case .del:
                        print("\(serial) disconnected")
                        self.connections.removeValue(forKey: serial)
                    default:
                        print("Unknown event method")
                        SentrySDK.capture(message: "Unknown event method")
                    }
                } catch {
                    print(error)
                    SentrySDK.capture(error: error)
                }
            })
    }
    
    func startScan() {
        sensors = [:]
        
        scanState = .On
        bleCentral.scanForPeripherals(withServices: nil, options: nil)
        
        // Reset existing timer and restart a timer to stop scanning after 10 seconds
        if scanTimer != nil && scanTimer!.isValid {
            scanTimer!.invalidate()
        }
        scanTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(stopScan), userInfo: nil, repeats: false)
        if let scanTimer = scanTimer {
            RunLoop.main.add(scanTimer, forMode: .common)
        }
    }
    
    @objc func stopScan() {
        bleCentral.stopScan()
        scanTimer?.invalidate()
        scanState = .Off
    }

    // Attempt to connect to a sensor
    func connect(identifier: UUID) {
        print("Connecting to \(identifier)")
        sensors[identifier]!.connectionState = .Connecting
        self.mds.connectPeripheral(with: sensors[identifier]!.peripheral.identifier);
    }
    
    // Get information about the firmware installed on the sensor
    func getAppInfo(serial: String) async throws -> MovesenseAppInfo {
        let response = await mds.doGet("\(serial)/Info/App", contract: [:])
        let decoded = try self.decoder.decode(MovesenseResponseContainer<MovesenseAppInfo>.self, from: response.bodyData)
        return decoded.content
    }
    
    // Get information about the bootloader installed on the sensor
    func getSensorInfo(serial: String) async throws -> MovesenseInfo {
        let response = await mds.doGet("\(serial)/Info", contract: [:])
        let decoded = try self.decoder.decode(MovesenseResponseContainer<MovesenseInfo>.self, from: response.bodyData)
        return decoded.content
    }
    
    func stopRecording(serial: String) {
        mds.doUnsubscribe("\(serial)/Sample/IntAcc/13")
        self.connections[serial]?.lastMeasurement = Date.distantPast
        //Task { try await updateRecordingStatus(serial: serial) }
    }
    
    // Disable future autoconnections for this sensor
    func forgetSensor(serial: String, uuid: UUID) {
        mds.disableAutoReconnectForDevice(withSerial: serial)
        mds.disconnectPeripheral(with: uuid)
    }
    
    func startRecording(serial: String) async {
        mds.doSubscribe(
            "\(serial)/Sample/IntAcc/13",
            contract: [:],
            response: { (response) in
                if response.statusCode < 300 {
                    print("Subscription to IntAcc successful")
                    //Task { try await self.updateRecordingStatus(serial: serial) }
                } else {
                    print("Subscription to IntAcc failed:")
                    print(response.header["Uri"] as! String, response.header["Reason"] as! String)
                }
            },
            onEvent: { (event) in
                do {
                    if self.sessionEntity == nil {
                        // this is the first connection, start a session
                        let session = SessionEntity(context: self.moc!)
                        session.date = Date()
                        self.sessionEntity = session
                    }
                    
                    let sensors = self.sessionEntity?.sensors?.allObjects as? [SensorEntity]
                    var sensor = sensors!.first(where: { $0.serial == serial })
                    
                    if sensor == nil {
                        sensor = SensorEntity(context: self.moc!)
                        sensor!.session = self.sessionEntity
                        sensor!.serial = serial
                    }
                    
                    let decodedEvent = try self.decoder.decode(MovesenseEventContainer<SkisensorMeasurement>.self, from: event.bodyData)
                    let ts = Double(decodedEvent.body.Timestamp) / 1000.0
                    
                    self.connections[serial]?.lastMeasurement = Date()

                    let acc = decodedEvent.body.Acc
                    let INT16_MAX: Double = 32767
                    let ONE_G = (9.832 + 9.780) * 0.5
                    let accScale = INT16_MAX / (ONE_G * 8)
                    
                    let gyro = decodedEvent.body.Gyro
                    let gyroScale = INT16_MAX / 500
                    
                    let magn = decodedEvent.body.Magn
                    let magnScale = INT16_MAX / 5000
                    
                    let measurement = MeasurementEntity(context: self.moc!)
                    let a = Value3dEntity(context: self.moc!)
                    a.x = Double(acc.x) / accScale
                    a.y = Double(acc.y) / accScale
                    a.z = Double(acc.z) / accScale
                    measurement.acc = a
                    
                    let g = Value3dEntity(context: self.moc!)
                    g.x = Double(gyro.x) / gyroScale
                    g.y = Double(gyro.y) / gyroScale
                    g.z = Double(gyro.z) / gyroScale
                    measurement.gyro = g
                    
                    let m = Value3dEntity(context: self.moc!)
                    m.x = Double(magn.x) / magnScale
                    m.y = Double(magn.y) / magnScale
                    m.z = Double(magn.z) / magnScale
                    measurement.magn = m
                    
                    measurement.timestamp = Date()
                    measurement.sensor = sensor
                    
                    try? self.moc!.save()
                } catch {
                    print(error)
                    SentrySDK.capture(error: error)
                }
            })
    }
    
    // A new sensor has been found during a scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let isMovesense = peripheral.name?.hasPrefix("Movesense") {
            if isMovesense {
                var connectionState = ConnectionState.Unconnected
                if (sensors[peripheral.identifier] != nil) {
                    connectionState = sensors[peripheral.identifier]!.connectionState
                }
                sensors[peripheral.identifier] = MovesenseSensor(peripheral: peripheral, name: peripheral.name ?? "NoName", connectionState: connectionState)
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        }
        else {
            isSwitchedOn = false
        }
    }
}
