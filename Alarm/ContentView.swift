//
//  ContentView.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            CameraView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
