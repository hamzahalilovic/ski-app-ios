//
//  StorageController.swift
//  Skisensor2


import Foundation
import CoreData

class StorageController: ObservableObject {
    let container = NSPersistentContainer(name: "Skisensor")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}

extension SessionEntity {
    func maxAcceleration() -> Double {
        self.sensors!.map({ s in
            (s as! SensorEntity).maxAcceleration()
        }).max() ?? 0
    }
    
    func maxRoll() -> Double {
        self.sensors!.map({ s in
            (s as! SensorEntity).maxRoll()
        }).max() ?? 0
    }
}

extension SensorEntity {
    func maxAcceleration() -> Double {
        self.measurements!.map({ m in
            (m as! MeasurementEntity).acceleration()
        }).max() ?? 0
    }
    
    func maxRoll() -> Double {
        self.measurements!.map({ m in
            (m as! MeasurementEntity).roll()
        }).max() ?? 0
    }
    
    func accelerations() -> [(Int, Double)] {
        let accs = self.measurements!.map({ m in
            (m as? MeasurementEntity)!.acceleration()
        })
        return Array(zip(Array(0..<accs.count), accs))
    }
    
    func rolls() -> [(Int, Double)] {
        let rolls = self.measurements!.map({ m in
            (m as? MeasurementEntity)!.roll()
        })
        return Array(zip(Array(0..<rolls.count), rolls))
    }
}

extension MeasurementEntity {
    func acceleration() -> Double {
        let accX = acc!.x
        let accY = acc!.y
        let accZ = acc!.z
        let sumOfSquares = accX * accX + accY * accY + accZ * accZ
        let result = sqrt(Double(sumOfSquares))
        return result / 9.81
    }
    
    func roll() -> Double {
        let accY = acc!.y
        let accZ = acc!.z
        let rollAngleRadians = atan2(accY, accZ)
        let rollAngleDegrees = rollAngleRadians * (180.0 / Double.pi)
        return rollAngleDegrees
    }
}
