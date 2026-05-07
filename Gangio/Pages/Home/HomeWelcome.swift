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
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 12) {
                            HomeButton(
                                title: "Discover Communities",
                                description: "Explore public servers and find your tribe",
                                iconName: "safari.fill",
                                color: Color.blue
                            ) {
                                viewState.path.append(NavigationDestination.discover)
                            }
                            
                            HomeButton(
                                title: "Testers Hub",
                                description: "Join our official server and help us improve",
                                iconName: "star.bubble.fill",
                                color: Color.purple
                            ) {
                                viewState.path.append(NavigationDestination.invite("Testers"))
                            }
                            
                            HomeButton(
                                title: "Support Gangio",
                                description: "Help keep the project alive with a donation",
                                iconName: "heart.circle.fill",
                                color: Color.pink
                            ) {
                                openURL(URL(string: "https://ko-fi.com/gangiochat")!)
                            }
                            
                            HomeButton(
                                title: "App Settings",
                                description: "Customize your experience and appearance",
                                iconName: "gearshape.fill",
                                color: Color.gray
                            ) {
                                viewState.path.append(NavigationDestination.settings)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color)
    }
}

struct HomeButton: View {
    @EnvironmentObject var viewState: AppViewState
    
    var title: String
    var description: String
    var iconName: String
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(viewState.theme.foreground2.color)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground2.color.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewState.theme.background2.color)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
