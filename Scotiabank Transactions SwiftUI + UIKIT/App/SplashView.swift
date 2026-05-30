//
//  SplashView.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Brief branded launch splash: the Scotiabank wordmark on the brand-red field,
//  shown over the list while it loads and faded out by the app entry point. Kept
//  as its own `View` struct (not an inline closure) per the project conventions.
//

import SwiftUI

struct SplashView: View {

    var body: some View {
        ZStack {
            Theme.Palette.brandRed
            Text("Scotiabank")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scotiabank")
    }
}

#Preview {
    SplashView()
}
