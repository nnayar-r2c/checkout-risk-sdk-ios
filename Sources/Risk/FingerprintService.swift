//
//  FingerprintService.swift
//  
//
//  Created by Precious Ossai on 31/10/2023.
//

import FingerprintPro
import Foundation

final class FingerprintService {
    private var requestID: String?
    private let client: FingerprintClientProviding
    private let internalConfig: RiskSDKInternalConfig
    private let loggerService: LoggerService
    
    init(fingerprintPublicKey: String, internalConfig: RiskSDKInternalConfig, loggerService: LoggerService) {
        let customDomain: Region = .custom(domain: internalConfig.fingerprintEndpoint)
        let configuration = Configuration(apiKey: fingerprintPublicKey, region: customDomain)
        client = FingerprintProFactory.getInstance(configuration)
        self.internalConfig = internalConfig
        self.loggerService = loggerService
    }
    
    func publishData(completion: @escaping (Result<String, RiskError>) -> Void) {
        
        guard requestID == nil else {
            return completion(.success(requestID!))
        }
        
        let metadata = createMetadata(sourceType: internalConfig.sourceType.rawValue)
        
        client.getVisitorIdResponse(metadata) { [weak self] result in
            
            switch result {
            case .failure:
                self?.loggerService.log(riskEvent: .publishFailure)

                return completion(.failure(RiskError.description("Error publishing risk data")))
            case let .success(response):
                self?.loggerService.log(riskEvent: .collected, requestID: response.requestId)
                self?.requestID = response.requestId
                
                completion(.success(response.requestId))
            }
        }
    }
    
    func createMetadata(sourceType: SourceType.RawValue) -> Metadata {
        var meta = Metadata()
        meta.setTag(sourceType, forKey: "fpjsSource")
        meta.setTag(Date().timeIntervalSince1970 * 1000, forKey: "fpjsTimestamp")
        
        return meta
    }
    
}
