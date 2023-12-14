//
//  ContentView.swift
//  Skisensor2


import SwiftUI
import Charts
import CoreData

struct ContentView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SessionEntity.date, ascending: false)]) var sessions: FetchedResults<SessionEntity>
    @Environment(\.managedObjectContext) var moc
    @StateObject var bleController = BLEController()
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: SensorsView(moc: moc)) {
                    Text("Start new session")
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                Spacer()
                List {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            Grid(alignment: .leading) {
                                Spacer()
                                GridRow {
                                    Text("Date")
                                    Text(session.date?.formatted() ?? "Unknown date").fontWeight(.bold)
                                }
                                Spacer()
                                GridRow {
                                    Text("Duration")
                                    Text(String(session.duration)).fontWeight(.bold)
                                }
                                Spacer()
                                GridRow {
                                    Text("G-Force")
                                    Text("\(round(num: session.maxAcceleration()))g").fontWeight(.bold)
                                }
                                Spacer()
                                GridRow {
                                    Text("Leaning")
                                    Text("\(round(num: session.maxRoll()))°").fontWeight(.bold)
                                }
                                Spacer()
                            }
                        }
                    }.onDelete(perform: deleteSessions)
                }
            }.navigationTitle("Sessions")
        }.environmentObject(bleController)
            .onAppear {
                bleController.moc = moc
            }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(moc.delete)
            try? moc.save()
        }
    }
}

struct SensorsView: View {
    let moc: NSManagedObjectContext
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
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
}

struct SessionDetailView: View {
    let session: SessionEntity
    
    var body: some View {
        VStack {
            Text("G-Force").font(.title2)
            ForEach((session.sensors?.allObjects as? [SensorEntity])!) { sensor in
                VStack {
                    Text(sensor.serial!)
                    Chart(sensor.accelerations(), id: \.0) { tuple in
                        LineMark(
                            x: .value("X values", tuple.0),
                            y: .value("Y values", tuple.1)
                        )
                    }
                }
            }
            
            Text("Roll").font(.title3)
            ForEach((session.sensors?.allObjects as? [SensorEntity])!) { sensor in
                VStack {
                    Text(sensor.serial!)
                    Chart(sensor.rolls(), id: \.0) { tuple in
                        LineMark(
                            x: .value("X values", tuple.0),
                            y: .value("Y values", tuple.1)
                        )
                    }
                }
            }

            Spacer()
        }.navigationTitle(session.date?.formatted() ?? "Unknown date")
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


            if connection.lastMeasurement == nil || (Date() - connection.lastMeasurement! > 5) {
                Text("Not recording.")
            } else {
                Text("Recording\(String(repeating: ".", count: Calendar.current.component(.second, from: connection.lastMeasurement!) % 3 + 1))")
            }
            
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

func round(num: Double) -> String {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2

    return formatter.string(from: NSNumber(value: num)) ?? ""
}

#Preview {
    ContentView()
}
