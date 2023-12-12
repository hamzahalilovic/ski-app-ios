//
//  MovesenseTypes.swift
//  SkiApp


import Foundation

struct MovesenseEventContainer<T: Decodable>: Decodable {

    let body: T
    let uri: String
    let method: String
}

struct MovesenseResponseContainer<T: Decodable>: Decodable {

    let content: T
}

struct MovesenseConnectionInfo: Codable {

    let connectionType: String
    let connectionUuid: UUID
}

struct MovesenseDeviceEventBody: Codable {

    let serialNumber: String
    let connectionInfo: MovesenseConnectionInfo?
    let deviceInfo: MovesenseDeviceInfo?
}

struct MovesenseDeviceEventStatus: Codable {

    let status: MovesenseResponseCode
}

struct MovesenseDeviceEvent: Codable {

    let eventUri: String
    let eventStatus: MovesenseDeviceEventStatus
    let eventMethod: MovesenseMethod
    let eventBody: MovesenseDeviceEventBody
}

public typealias MovesenseSerialNumber = String

public enum MovesenseMethod: String, Codable {
    case get = "GET"
    case put = "PUT"
    case del = "DEL"
    case post = "POST"
    case subscribe
    case unsubscribe
}

public enum MovesenseError: Error {
    case integrityError(String)
    case controllerError(String)
    case decodingError(String)
    case requestError(String)
    case deviceError(String)
}

public enum MovesenseResponseCode: Int, Codable {
    case unknown = 0
    case ok = 200
    case created = 201
    case badRequest = 400
    case notFound = 404
    case conflict = 409
}

public struct MovesenseAddressInfo: Codable {

    public let address: String
    public let name: String
}

public struct MovesenseInfo: Codable {

    public let manufacturerName: String
    public let brandName: String?
    public let productName: String
    public let variantName: String
    public let design: String?
    public let hwCompatibilityId: String
    public let serialNumber: String
    public let pcbaSerial: String
    public let swVersion: String
    public let hwVersion: String
    public let additionalVersionInfo: String?
    public let addressInfo: [MovesenseAddressInfo]
    public let apiLevel: String
}

public struct MovesenseDeviceInfo: Codable {

    public let description: String
    public let mode: Int
    public let name: String
    public let serialNumber: String
    public let swVersion: String
    public let hwVersion: String
    public let hwCompatibilityId: String
    public let manufacturerName: String
    public let pcbaSerial: String
    public let productName: String
    public let variantName: String
    public let addressInfo: [MovesenseAddressInfo]
}

public struct MovesenseHeartRate: Codable {

    public let average: Float
    public let rrData: [Int]
}

public struct MovesenseAcc: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
    public init(timestamp: UInt32, vectors: [MovesenseVector3D]) {
        self.timestamp = timestamp
        self.vectors = vectors
    }
}

public struct MovesenseAccConfig: Codable {

    public let gRange: UInt8
}

public struct MovesenseAccInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt8]
}

public struct MovesenseAppInfo: Codable {

    public let name: String
    public let version: String
    public let company: String
}

public struct MovesenseEcg: Codable {

    public let timestamp: UInt32
    public let samples: [Int32]
    public init(timestamp: UInt32, samples: [Int32]) {
        self.timestamp = timestamp
        self.samples = samples
    }
}

public struct MovesenseEcgInfo: Codable {

    public let currentSampleRate: UInt16
    public let availableSampleRates: [UInt16]
    public let arraySize: UInt16
}

public struct MovesenseGyro: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
    public init(timestamp: UInt32, vectors: [MovesenseVector3D]) {
        self.timestamp = timestamp
        self.vectors = vectors
    }
}

public struct MovesenseGyroConfig: Codable {

    public let dpsRange: UInt16
}

public struct MovesenseSystemTime: Codable {

    public let value: Int64
}

public struct MovesenseGyroInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt16]
}

public struct MovesenseMagn: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
    public init(timestamp: UInt32, vectors: [MovesenseVector3D]) {
        self.timestamp = timestamp
        self.vectors = vectors
    }
}

public struct MovesenseMagnInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt16]
}

public struct MovesenseIMU: Codable {

    public let timestamp: UInt32
    public let accVectors: [MovesenseVector3D]
    public let gyroVectors: [MovesenseVector3D]
    public init(timestamp: UInt32, accVectors: [MovesenseVector3D], gyroVectors: [MovesenseVector3D]) {
        self.timestamp = timestamp
        self.accVectors = accVectors
        self.gyroVectors = gyroVectors
    }
}

public struct MovesenseSystemEnergy: Codable {

    public let percentage: UInt8
    public let milliVolts: UInt16?
    public let internalResistance: UInt8?
}

public struct MovesenseSystemMode: Codable {

    let currentMode: UInt8
    let nextMode: UInt8?
}

public struct MovesenseVector3D: Codable {

    public let x: Float
    public let y: Float
    public let z: Float
}

extension MovesenseConnectionInfo {

    enum CodingKeys: String, CodingKey {
        case connectionType = "Type"
        case connectionUuid = "UUID"
    }
}

extension MovesenseDeviceInfo {

    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case mode = "Mode"
        case name = "Name"
        case serialNumber = "Serial"
        case swVersion = "SwVersion"
        case hwVersion = "hw"
        case hwCompatibilityId = "hwCompatibilityId"
        case manufacturerName = "manufacturerName"
        case pcbaSerial = "pcbaSerial"
        case productName = "productName"
        case variantName = "variant"
        case addressInfo = "addressInfo"
    }
}

extension MovesenseInfo {

    enum CodingKeys: String, CodingKey {
        case manufacturerName = "manufacturerName"
        case brandName = "brandName"
        case productName = "productName"
        case variantName = "variant"
        case design = "design"
        case hwCompatibilityId = "hwCompatibilityId"
        case serialNumber = "serial"
        case pcbaSerial = "pcbaSerial"
        case swVersion = "sw"
        case hwVersion = "hw"
        case addressInfo = "addressInfo"
        case additionalVersionInfo = "additionalVersionInfo"
        case apiLevel = "apiLevel"
    }
}

extension MovesenseDeviceEventBody {

    enum CodingKeys: String, CodingKey {
        case serialNumber = "Serial"
        case connectionInfo = "Connection"
        case deviceInfo = "DeviceInfo"
    }
}

extension MovesenseDeviceEventStatus {

    enum CodingKeys: String, CodingKey {
        case status = "Status"
    }
}

extension MovesenseDeviceEvent {

    enum CodingKeys: String, CodingKey {
        case eventStatus = "Response"
        case eventMethod = "Method"
        case eventUri = "Uri"
        case eventBody = "Body"
    }
}

extension MovesenseHeartRate {

    enum CodingKeys: String, CodingKey {
        case average
        case rrData
    }
}

extension MovesenseEventContainer {

    enum CodingKeys: String, CodingKey {
        case body = "Body"
        case uri = "Uri"
        case method = "Method"
    }
}

extension MovesenseResponseContainer {

    enum CodingKeys: String, CodingKey {
        case content = "Content"
    }
}

extension MovesenseEcgInfo {

    enum CodingKeys: String, CodingKey {
        case currentSampleRate = "CurrentSampleRate"
        case availableSampleRates = "AvailableSampleRates"
        case arraySize = "ArraySize"
    }
}

extension MovesenseEcg {

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case samples = "Samples"
    }
}

extension MovesenseAcc {

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case vectors = "ArrayAcc"
    }
}

extension MovesenseAccConfig {

    enum CodingKeys: String, CodingKey {
        case gRange = "GRange"
    }
}

extension MovesenseAccInfo {

    enum CodingKeys: String, CodingKey {
        case sampleRates = "SampleRates"
        case ranges = "Ranges"
    }
}

extension MovesenseGyro {

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case vectors = "ArrayGyro"
    }
}

extension MovesenseGyroConfig {

    enum CodingKeys: String, CodingKey {
        case dpsRange = "DPSRange"
    }
}

extension MovesenseGyroInfo {

    enum CodingKeys: String, CodingKey {
        case sampleRates = "SampleRates"
        case ranges = "Ranges"
    }
}

extension MovesenseMagn {

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case vectors = "ArrayMagn"
    }
}

extension MovesenseMagnInfo {

    enum CodingKeys: String, CodingKey {
        case sampleRates = "SampleRates"
        case ranges = "Ranges"
    }
}

extension MovesenseIMU {

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case accVectors = "ArrayAcc"
        case gyroVectors = "ArrayGyro"
    }
}

extension MovesenseSystemEnergy {

    enum CodingKeys: String, CodingKey {
        case percentage = "Percent"
        case milliVolts = "MilliVoltages"
        case internalResistance = "InternalResistance"
    }
}

extension MovesenseSystemMode {

    enum CodingKeys: String, CodingKey {
        case currentMode = "current"
        case nextMode = "next"
    }
}
