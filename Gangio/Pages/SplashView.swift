//
//  SplashView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = true
    @State private var loadingMessage = ""
    
    private let loadingMessages = [
        "Reticulating splines…",
        "Summoning your squad.",
        "Bribing the servers to go faster.",
        "Checking if your mic is on. It is.",
        "Untangling the chat history.",
        "Teaching the bots to behave.",
        "Warming up the voice channels.",
        "Giving the hamsters a coffee break.",
        "Almost there. Probably.",
        "Dusting off the notifications.",
        "Making sure nobody's on light mode.",
        "Sharpening the ping.",
        "Synchronizing vibes.",
        "Polishing the pixels.",
        "Asking the servers nicely.",
        "Preparing your unread messages. Sorry in advance.",
        "Counting the online members. There are a lot.",
        "Good things take time. So does Gangio."
    ]
    
    var body: some View {
        ZStack {
            // Theme-based background
            if colorScheme == .dark {
                Color.black.ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }
            
            VStack(spacing: 20) {
                // Wide logo in center
                Image("wide")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 60)
                    .if(colorScheme == .dark) { view in
                        view.colorInvert()
                    }
                
                // Loading message
                Text(loadingMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            // Set random loading message
            loadingMessage = loadingMessages.randomElement() ?? "Loading..."
            
            // Show splash screen for 2 seconds then dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isVisible = false
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
    }
}

#Preview {
    SplashView()
}
