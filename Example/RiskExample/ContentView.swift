//
//  ContentView.swift
//  RiskExample
//
//  Created by Precious Ossai on 11/10/2023.
//

import SwiftUI
import Risk

import Foundation

struct ContentView: View {
	@State private var deviceSessionId: String = ""
	@State private var checked: Bool = false
	
	var body: some View {
		Text("Risk iOS Example").padding(.bottom).frame(maxWidth: .infinity, alignment: .center).font(.title)
		
		VStack(alignment: .leading) {
			
			Text("Card no: 0000 1234 6549 15151")
			Text("Card exp: 12/26")
			Text("Card CVV: 500").padding(.bottom)
			
		}
		.padding().background(Color.gray.opacity(0.1))
		
		Button("Pay $1400") {
			let yourConfig = RiskConfig(publicKey: "pk_qa_7wzteoyh4nctbkbvghw7eoimiyo", environment: RiskEnvironment.qa)
			
			Risk.createInstance(config: yourConfig) { riskInstance in
				riskInstance?.publishData() { response in
					checked = true
					deviceSessionId = response?.deviceSessionId ?? ""
				}
			}
		}.padding().background(Color.blue.opacity(0.9)).cornerRadius(8).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.white).padding(.top)
		
		Text(!checked ? "" : "Device session id: \(deviceSessionId)").padding(.top).multilineTextAlignment(.center)
	}
}

#Preview {
	ContentView()
}
