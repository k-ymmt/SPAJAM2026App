//
//  ContentView.swift
//  SPAJAM2026App
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

import SwiftUI

/// Entry screen: a blank white screen. Shake the device to open the debug menu sheet.
struct ContentView: View {
    @State private var isDebugMenuPresented = false

    var body: some View {
        Color.white
            .ignoresSafeArea()
            .onShake {
                isDebugMenuPresented = true
            }
            .sheet(isPresented: $isDebugMenuPresented) {
                DebugMenuView()
            }
    }
}

#Preview {
    ContentView()
}
