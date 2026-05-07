//
//  ContentView.swift
//  ResumeBuilder IOS APP
//
//  Created by Nadav Yigal on 03/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("ResumeBuilder iOS")
                .font(.title2)
            Text("App shell is running. Wire this to your RootView once compilation issues are resolved.")
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
