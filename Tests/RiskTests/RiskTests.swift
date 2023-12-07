//
//  RiskTests.swift
//  RiskTests
//  Tests
//
//  Created by Precious Ossai on 31/10/2023.
//

import XCTest
@testable import Risk

class RiskTests: XCTestCase {

    func testGetInstanceWithValidConfiguration() {
        let expectation = self.expectation(description: "Risk instance creation")
        var createdRiskInstance: Risk?
        
        guard let publicKey = ProcessInfo.processInfo.environment["SAMPLE_MERCHANT_PUBLIC_KEY"] else {
            XCTFail("Environment variable SAMPLE_MERCHANT_PUBLIC_KEY is not set.")
            return
        }

        let validConfig = RiskConfig(publicKey: publicKey, environment: RiskEnvironment.qa)

        Risk.getInstance(config: validConfig) { risk in
            createdRiskInstance = risk
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertNotNil(createdRiskInstance)
    }

    func testGetInstanceWithInvalidPublicKey() {
        let expectation = self.expectation(description: "Risk instance creation with invalid public key")
        var createdRiskInstance: Risk?

        let invalidConfig = RiskConfig(publicKey: "invalid_public_key", environment: RiskEnvironment.qa)

        Risk.getInstance(config: invalidConfig) { risk in
            createdRiskInstance = risk
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertNil(createdRiskInstance)
    }
}
