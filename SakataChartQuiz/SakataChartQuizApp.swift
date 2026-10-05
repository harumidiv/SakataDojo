//
//  SakataChartQuizApp.swift
//  SakataChartQuiz
//
//  Created by harumi.sagawa on 2026/08/05.
//

import SwiftUI
import GoogleMobileAds

@main
struct SakataChartQuizApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
