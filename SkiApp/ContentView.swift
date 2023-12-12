//
//  ContentView.swift
//  SkiApp


import SwiftUI
import Charts

struct ContentView: View {
    @StateObject var bleController = BLEController()
    
    var body: some View {
        NavigationView {
            VStack {
                Button {
                    bleController.startScan()
                } label: {
                    Text("Add new Sensor")
                    if bleController.scanState == .On { ProgressView() }
                }.buttonStyle(.bordered)
                if !bleController.sensors.isEmpty {
                    List {
                        ForEach(Array(bleController.sensors), id: \.key) { uuid, sensor in
                            HStack {
                                Text(sensor.name)
                                Button {
                                    bleController.connect(identifier: sensor.peripheral.identifier)
                                } label: {
                                    Text("Connect")
                                    if sensor.connectionState == .Connecting { ProgressView() }
                                }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                Text("Known sensors will automatically be listed below.")
                List(Array(bleController.connections), id: \.key) { serial, connection in
                    NavigationLink(destination: SensorDetailView(connection: connection)) {
                        Text(connection.serial)
                    }
                }
            }
            .padding()
            .navigationTitle("Sensors")
        }
        .environmentObject(bleController)
    }
}

struct SensorDetailView: View {
    @EnvironmentObject var bleController: BLEController

    let connection: MovesenseConnection

    var body: some View {
        VStack {
            Text("Software: \(connection.firmwareName) by \(connection.firmwareManufacturer)")
            Text("SW Version: \(connection.firmwareVersion), Bootloader: \(connection.bootloaderVersion)")
            
            Spacer()

            HStack {
                Button {
                    Task {
                        await bleController.startRecording(serial: connection.serial)
                    }
                } label: {
                    Text("Start Recording")
                }.buttonStyle(.bordered)

                Button {
                    bleController.stopRecording(serial: connection.serial)
                } label: {
                    Text("Stop Recording")
                }.buttonStyle(.bordered)
            }
            
            Spacer()
            
            Text("Accelerometer")
            Chart(connection.accData) {
                LineMark(x: .value("Pos", $0.id), y: .value("Val", $0.value)).foregroundStyle(by: .value("Axis", $0.axis))
            }.chartXScale(domain: (connection.accData.first?.id ?? 0)...(connection.accData.last?.id ?? 0))
            
            Spacer()
            
            Text("Gyroscope")
            Chart(connection.gyroData) {
                LineMark(x: .value("Pos", $0.id), y: .value("Val", $0.value)).foregroundStyle(by: .value("Axis", $0.axis))
            }.chartXScale(domain: (connection.gyroData.first?.id ?? 0)...(connection.gyroData.last?.id ?? 0))
            
            Spacer()
            
            Text("Magnetometer")
            Chart(connection.magnData) {
                LineMark(x: .value("Pos", $0.id), y: .value("Val", $0.value)).foregroundStyle(by: .value("Axis", $0.axis))
            }.chartXScale(domain: (connection.magnData.first?.id ?? 0)...(connection.magnData.last?.id ?? 0))
            
            Spacer()
            
            Button {
                bleController.forgetSensor(serial: connection.serial, uuid: connection.uuid)
            } label: {
                Text("Forget")
            }.accentColor(.red).buttonStyle(.bordered)
            
            Spacer()
        }.navigationTitle(connection.serial)
    }
}

#Preview {
    ContentView()
}
