//
//  LoggerService.swift
//
//
//  Created by Precious Ossai on 21/11/2023.
//

import Foundation
import CheckoutEventLoggerKit
import UIKit

enum RiskEvent: String, Codable {
    case publishDisabled = "riskDataPublishDisabled"
    case published = "riskDataPublished"
    case publishFailure = "riskDataPublishFailure"
    case collected = "riskDataCollected"
    case loadFailure = "riskLoadFailure"
}

struct Elapsed {
    let block: Double? // time to retrieve configuration or loadFailure
    let deviceDataPersist: Double? // time to persist data
    let fpload: Double? // time to load fingerprint
    let fppublish: Double? // time to publish fingerprint data
    let total: Double? // total time

    private enum CodingKeys: String, CodingKey {
        case block = "Block", deviceDataPersist = "DeviceDataPersist", fpload = "FpLoad", fppublish = "FpPublish", total = "Total"
    }
}

struct RiskLogError {
    let reason: String // service method
    let message: String // description of error
    let status: Int? // status code
    let type: String? // Error type

    private enum CodingKeys: String, CodingKey {
        case reason = "Reason", message = "Message", status = "Status", type = "Type"
    }
}

protocol LoggerServiceProtocol {
    init(internalConfig: RiskSDKInternalConfig)
    func log(riskEvent: RiskEvent, blockTime: Double?, deviceDataPersistTime: Double?, fpLoadTime: Double?, fpPublishTime: Double?, deviceSessionId: String?, requestId: String?, error: RiskLogError?)
}

extension LoggerServiceProtocol {
    func formatEvent(internalConfig: RiskSDKInternalConfig, riskEvent: RiskEvent, deviceSessionId: String?, requestId: String?, error: RiskLogError?, latencyMetric: Elapsed) -> Event {
        let maskedPublicKey = getMaskedPublicKey(publicKey: internalConfig.merchantPublicKey)
        let ddTags = getDDTags(environment: internalConfig.environment.rawValue)
        var monitoringLevel: MonitoringLevel
        let properties: [String: AnyCodable]

        switch riskEvent {
        case .published, .collected:
            monitoringLevel = .info
        case .publishFailure, .loadFailure:
            monitoringLevel = .error
        case .publishDisabled:
            monitoringLevel = .warn
        }

        #if DEBUG
        monitoringLevel = .debug
        #endif

        switch riskEvent {
        case .published, .collected:
            properties = [
                "Block": AnyCodable(latencyMetric.block),
                "CorrelationId": AnyCodable(internalConfig.correlationId),
                "DeviceDataPersist": AnyCodable(latencyMetric.deviceDataPersist),
                "FpLoad": AnyCodable(latencyMetric.fpload),
                "FpPublish": AnyCodable(latencyMetric.fppublish),
                "Total": AnyCodable(latencyMetric.total),
                "EventType": AnyCodable(riskEvent.rawValue),
                "FramesMode": AnyCodable(internalConfig.framesMode),
                "MaskedPublicKey": AnyCodable(maskedPublicKey),
                "ddTags": AnyCodable(ddTags),
                "RiskSDKVersion": AnyCodable(Constants.riskSdkVersion),
                "Timezone": AnyCodable(TimeZone.current.identifier),
                "FpRequestId": AnyCodable(requestId),
                "DeviceSessionId": AnyCodable(deviceSessionId),
            ]
        case .publishFailure, .loadFailure, .publishDisabled:
            properties = [
                "Block": AnyCodable(latencyMetric.block),
                "CorrelationId": AnyCodable(internalConfig.correlationId),
                "DeviceDataPersist": AnyCodable(latencyMetric.deviceDataPersist),
                "FpLoad": AnyCodable(latencyMetric.fpload),
                "FpPublish": AnyCodable(latencyMetric.fppublish),
                "Total": AnyCodable(latencyMetric.total),
                "EventType": AnyCodable(riskEvent.rawValue),
                "FramesMode": AnyCodable(internalConfig.framesMode),
                "MaskedPublicKey": AnyCodable(maskedPublicKey),
                "ddTags": AnyCodable(ddTags),
                "RiskSDKVersion": AnyCodable(Constants.riskSdkVersion),
                "Timezone": AnyCodable(TimeZone.current.identifier),
                "ErrorMessage": AnyCodable(error?.message),
                "ErrorType": AnyCodable(error?.type),
                "ErrorReason": AnyCodable(error?.reason),
            ]
        }

        return Event(
            typeIdentifier: Constants.loggerTypeIdentifier,
            time: Date(),
            monitoringLevel: monitoringLevel,
            properties: properties
        )
    }

    func getMaskedPublicKey (publicKey: String) -> String {
        return "\(publicKey.prefix(8))********\(publicKey.suffix(6))"
    }

    func getDDTags(environment: String) -> String {
        return "team:prism,service:prism.risk.ios,version:\(Constants.riskSdkVersion),env:\(environment)"
    }
}

struct LoggerService: LoggerServiceProtocol {
    private let internalConfig: RiskSDKInternalConfig
    private let logger: CheckoutEventLogging

    init(internalConfig: RiskSDKInternalConfig) {
        self.internalConfig = internalConfig
        self.logger = CheckoutEventLogger(productName: Constants.productName)
        setup()
    }

    private func setup() {

        let appBundle = Bundle.main
        let appPackageName = appBundle.bundleIdentifier ?? "unavailableAppPackageName"
        let appPackageVersion = appBundle
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unavailableAppPackageVersion"

        let deviceName = getDeviceModel()
        let osVersion = UIDevice.current.systemVersion
        let logEnvironment: Environment

        switch internalConfig.environment {
        case .qa, .sandbox:
            logEnvironment = .sandbox
        case .production:
            logEnvironment = .production
        }

        #if DEBUG
        logger.enableLocalProcessor(monitoringLevel: .debug)
        #endif

        logger.enableRemoteProcessor(
            environment: logEnvironment,
            remoteProcessorMetadata: RemoteProcessorMetadata(
                productIdentifier: Constants.productName,
                productVersion: Constants.riskSdkVersion,
                environment: internalConfig.environment.rawValue,
                appPackageName: appPackageName,
                appPackageVersion: appPackageVersion,
                deviceName: deviceName,
                platform: "iOS",
                osVersion: osVersion
            )
        )

    }

    func log(riskEvent: RiskEvent, blockTime: Double? = nil, deviceDataPersistTime: Double? = nil, fpLoadTime: Double? = nil, fpPublishTime: Double? = nil, deviceSessionId: String? = nil, requestId: String? = nil, error: RiskLogError? = nil) {
        
        let totalLatency = (blockTime ?? 0.00) + (deviceDataPersistTime ?? 0.00) + (fpLoadTime ?? 0.00) + (fpPublishTime ?? 0.00)
        
        let latencyMetric = Elapsed(block: blockTime, deviceDataPersist: deviceDataPersistTime, fpload: fpLoadTime, fppublish: fpPublishTime, total: totalLatency)
        
        let event = formatEvent(internalConfig: internalConfig, riskEvent: riskEvent, deviceSessionId: deviceSessionId, requestId: requestId, error: error, latencyMetric: latencyMetric)
        logger.log(event: event)
    }
    
    private func getDeviceModel() -> String {
        #if targetEnvironment(simulator)
        if let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return identifier
        }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
