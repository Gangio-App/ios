//
//  AppearanceSettings.swift
//  Gangio
//
//  Created by Angelo on 31/10/2023.
//

import Foundation
import SwiftUI


struct ThemeColorPicker: View {
    @Environment(\.self) var environment
    @EnvironmentObject var viewState: AppViewState
    
    var title: String
    @Binding var color: ThemeColor
    
    var body: some View {
        ColorPicker(selection: Binding {
            color.color
        } set: { new in
            withAnimation {
                color.set(with: new.resolve(in: environment))
            }
        }, label: {
            Text(title)
        })
    }
}

struct AppearanceSettings: View {
    @Environment(\.self) var environment
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewState: AppViewState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Theme Mode Selector
                SettingsSectionView(title: "Interface Style") {
                    HStack(spacing: 12) {
                        let isLightTheme = Theme.isLightOrDark(viewState.theme.background)
                        
                        ThemeModeButton(
                            title: "Light",
                            icon: "sun.max.fill",
                            isSelected: !viewState.theme.shouldFollowiOSTheme && isLightTheme
                        ) {
                            withAnimation {
                                let currentAccent = viewState.theme.accent
                                var newTheme = Theme.light
                                newTheme.accent = currentAccent
                                newTheme.shouldFollowiOSTheme = false
                                viewState.theme = newTheme
                            }
                        }

                        ThemeModeButton(
                            title: "Dark",
                            icon: "moon.fill",
                            isSelected: !viewState.theme.shouldFollowiOSTheme && !isLightTheme
                        ) {
                            withAnimation {
                                let currentAccent = viewState.theme.accent
                                var newTheme = Theme.dark
                                newTheme.accent = currentAccent
                                newTheme.shouldFollowiOSTheme = false
                                viewState.theme = newTheme
                            }
                        }

                        ThemeModeButton(
                            title: "System",
                            icon: "iphone",
                            isSelected: viewState.theme.shouldFollowiOSTheme
                        ) {
                            withAnimation {
                                let _ = viewState.applySystemScheme(theme: colorScheme, followSystem: true)
                            }
                        }
                    }
                    .padding(16)
                }

                // Accent Color
                SettingsSectionView(title: "Accent Color") {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewState.theme.accent.color)
                                .frame(width: 32, height: 32)
                        }
                        ThemeColorPicker(title: "Accent", color: $viewState.theme.accent)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                // Typography Settings
                SettingsSectionView(title: "Typography") {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 20))
                                .foregroundColor(viewState.theme.accent.color)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dynamic Type")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Text("Manage text scaling via iOS Settings")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // Chat Behavior Settings
                SettingsSectionView(title: "Chat Behavior") {
                    VStack(spacing: 0) {
                        // Message spacing slider
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewState.theme.accent.color)
                                Text("Message Spacing")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Text("\(Int(viewState.messageSpacing)) pt")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(viewState.theme.accent.color)
                                    .monospacedDigit()
                            }
                            Slider(value: $viewState.messageSpacing, in: 2...24, step: 1)
                                .tint(viewState.theme.accent.color)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Font Size")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Text("\(Int(viewState.messageFontSize)) pt")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                Slider(value: $viewState.messageFontSize, in: 10...32, step: 1)
                                    .tint(viewState.theme.accent.color)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        // Haptic toggle
                        Toggle(isOn: $viewState.scrollHapticEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewState.theme.accent.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scroll Haptic Feedback")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    Text("Vibration on scroll start")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(viewState.theme.accent.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(viewState.theme.background.color.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .animation(.easeInOut, value: viewState.theme)
    }
}

// MARK: - Theme Mode Button
struct ThemeModeButton: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.8))
                        : (colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
                    )
            )
        }
    }
}

struct AppearanceSettings_Preview: PreviewProvider {
    static var previews: some View {
        let viewState = AppViewState.preview()
        
        AppearanceSettings()
        .applyPreviewModifiers(withState: viewState.applySystemScheme(theme: .light))
        
        AppearanceSettings()
        .applyPreviewModifiers(withState: viewState.applySystemScheme(theme: .dark))
    }
}

