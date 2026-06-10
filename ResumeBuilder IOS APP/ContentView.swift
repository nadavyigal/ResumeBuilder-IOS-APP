//
//  ContentView.swift
//  ResumeBuilder IOS APP
//
//  Created by Nadav Yigal on 03/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if let slot = MarketingScreenshotSlot.current {
            MarketingScreenshotView(slot: slot)
        } else {
            RootView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
