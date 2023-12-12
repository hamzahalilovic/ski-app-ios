//
//  BLEManager.swift
//  SkiApp


import Foundation
import CoreBluetooth
import Movesense
import Sentry

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
    var accData: [MovesenseDatapoint] = []
    var gyroData: [MovesenseDatapoint] = []
    var magnData: [MovesenseDatapoint] = []
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

final class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isSwitchedOn = false
    
    @Published var scanState = ScanState.Off
    
    // Sensor in close vicinity, found by a scan but not connected
    @Published var sensors: Dictionary<UUID, MovesenseSensor> = [:]
    
    // Sensor connected to the mobile phone
    @Published var connections: Dictionary<String, MovesenseConnection> = [:]
    
    var bleCentral: CBCentralManager!
    var mds : MDSWrapper!
    var decoder = JSONDecoder()
    
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
                    let decodedEvent = try self.decoder.decode(MovesenseEventContainer<SkisensorMeasurement>.self, from: event.bodyData)
                    let ts = Double(decodedEvent.body.Timestamp) / 1000.0
                    let acc = decodedEvent.body.Acc
                    
                    let INT16_MAX: Double = 32767
                    let g = (9.832 + 9.780) * 0.5
                    let accScale = INT16_MAX / (g * 8)
                    self.connections[serial]!.accData.append(MovesenseDatapoint(id: ts, axis: "ax", value: Double(acc.x) / accScale))
                    self.connections[serial]!.accData.append(MovesenseDatapoint(id: ts, axis: "ay", value: Double(acc.y) / accScale))
                    self.connections[serial]!.accData.append(MovesenseDatapoint(id: ts, axis: "az", value: Double(acc.z) / accScale))

                    let gyro = decodedEvent.body.Gyro
                    let gyroScale = INT16_MAX / 500
                    self.connections[serial]!.gyroData.append(MovesenseDatapoint(id: ts, axis: "gx", value: Double(gyro.x) / gyroScale))
                    self.connections[serial]!.gyroData.append(MovesenseDatapoint(id: ts, axis: "gy", value: Double(gyro.y) / gyroScale))
                    self.connections[serial]!.gyroData.append(MovesenseDatapoint(id: ts, axis: "gz", value: Double(gyro.z) / gyroScale))

                    let magn = decodedEvent.body.Magn
                    let magnScale = INT16_MAX / 5000
                    self.connections[serial]!.magnData.append(MovesenseDatapoint(id: ts, axis: "mx", value: Double(magn.x) / magnScale))
                    self.connections[serial]!.magnData.append(MovesenseDatapoint(id: ts, axis: "my", value: Double(magn.y) / magnScale))
                    self.connections[serial]!.magnData.append(MovesenseDatapoint(id: ts, axis: "mz", value: Double(magn.z) / magnScale))
                    
                    if self.connections[serial]?.accData.count ?? 0 > 150 {
                        self.connections[serial]?.accData.removeFirst(3)
                    }
                    
                    if self.connections[serial]?.gyroData.count ?? 0 > 150 {
                        self.connections[serial]?.gyroData.removeFirst(3)
                    }
                    
                    if self.connections[serial]?.magnData.count ?? 0 > 150 {
                        self.connections[serial]?.magnData.removeFirst(3)
                    }
                    
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
