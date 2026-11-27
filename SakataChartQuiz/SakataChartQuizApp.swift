//
//  SakataChartQuizApp.swift
//  SakataChartQuiz
//
//  Created by harumi.sagawa on 2026/08/05.
//

import SwiftUI

@main
struct SakataChartQuizApp: App {
    @StateObject private var adRemoval = AdRemovalSubscription()

    var body: some Scene {
        WindowGroup {
            ContentView(adRemoval: adRemoval)
                // Synthesize the tanuki's voice up front so its first line in Beginner Mode isn't late.
                .task { MascotVoicePlayer.shared.preload() }
        }
    }
}
