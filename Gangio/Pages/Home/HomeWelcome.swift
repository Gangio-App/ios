//
//  HomeWelcome.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct HomeWelcome: View {
    @Environment(\.openURL) var openURL: OpenURLAction
    @EnvironmentObject var viewState: AppViewState
    var toggleSidebar: () -> ()

    var body: some View {
        let isDark = !Theme.isLightOrDark(viewState.theme.background)
        
        VStack(spacing: 0) {
            // Header with minimalist toolbar
            HStack {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground.color)
                }
                
                Spacer()
                
                Text("Home")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground.color)
                
                Spacer()
                
                // Placeholder to balance the sidebar button
                Color.clear.frame(width: 20, height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(viewState.theme.background.color.opacity(0.8))
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 16) {
                        Spacer(minLength: 40)
                        
                        ZStack {
                            // Subtle background glow
                            Circle()
                                .fill(viewState.theme.accent.color.opacity(0.15))
                                .frame(width: 200, height: 200)
                                .blur(radius: 50)
                            
                            VStack(spacing: 8) {
                                Text("Welcome to")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(viewState.theme.foreground2.color)
                                
                                Image("wide")
                                    .resizable()
                                    .maybeColorInvert(color: viewState.theme.background, isDefaultImage: false, defaultIsLight: true)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 44)
                                    .shadow(color: viewState.theme.accent.color.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                        }
                        
                        // Beta Disclaimer Card
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(viewState.theme.accent.color)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Early Beta Access")
                                    .font(.system(size: 15, weight: .bold))
                                
                                Text("The iOS app is currently in development. For the most stable experience, please use our web platform.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(viewState.theme.foreground2.color)
                                    .lineLimit(3)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(viewState.theme.accent.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(viewState.theme.accent.color.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    // Quick Actions Grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(viewState.theme.foreground3.color)
                            .tracking(2)
                            .padding(.horizontal, 24)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            HomeTile(
                                title: "Discovery",
                                icon: "safari.fill",
                                color: .blue
                            ) {
                                viewState.path.append(NavigationDestination.discover)
                            }
                            
                            HomeTile(
                                title: "Testers",
                                icon: "star.bubble.fill",
                                color: .purple
                            ) {
                                viewState.path.append(NavigationDestination.invite("Testers"))
                            }
                            
                            HomeTile(
                                title: "Donate",
                                icon: "heart.circle.fill",
                                color: .pink
                            ) {
                                openURL(URL(string: "https://ko-fi.com/gangiochat")!)
                            }
                            
                            HomeTile(
                                title: "Settings",
                                icon: "gearshape.fill",
                                color: .gray
                            ) {
                                viewState.path.append(NavigationDestination.settings)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color)
    }
}

struct HomeTile: View {
    @EnvironmentObject var viewState: AppViewState
    
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(viewState.theme.foreground.color)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(viewState.theme.background2.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewState.theme.foreground3.color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


#Preview {
    HomeWelcome(toggleSidebar: {})
        .applyPreviewModifiers(withState: AppViewState.preview())
}
