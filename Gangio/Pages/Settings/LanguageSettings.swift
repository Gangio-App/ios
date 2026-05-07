//
//  LanguageSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

//
//  LanguageSettings.swift
//  Gangio
//
//  Uses iOS 16+ native per-app language settings (Apple's recommended approach).
//  The app's language is controlled directly by the OS from Settings > Gangio > Language.
//  No custom language picker needed — this just redirects the user there.
//

import Foundation
import SwiftUI

struct LanguageSettings: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewState: AppViewState

    private var isDark: Bool { colorScheme == .dark }
    private var bg: Color { isDark ? Color(white: 0.07) : Color(white: 0.95) }
    private var card: Color { isDark ? Color(white: 0.12) : Color.white }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Info card
                    VStack(spacing: 14) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(viewState.theme.accent.color)

                        Text("Language")
                            .font(.title2.bold())

                        Text("Gangio uses iOS's built-in per-app language system.\n\nYou can set your preferred language — **English** or **Türkçe** — directly in your iPhone's Settings app under **Gangio → Language**.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Current language info
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current language")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(currentLanguageDisplay)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    // Open Settings button
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                            Text("Open Language Settings")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(viewState.theme.accent.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)

                    // Steps guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOW TO CHANGE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            stepRow(number: 1, text: "Tap \"Open Language Settings\" above")
                            stepRow(number: 2, text: "Scroll to find **Language** option")
                            stepRow(number: 3, text: "Choose **English** or **Türkçe**")
                            stepRow(number: 4, text: "Return to Gangio — it will switch automatically")
                        }
                    }
                    .padding(16)
                    .background(card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentLanguageDisplay: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "tr": return "🇹🇷 Türkçe"
        case "en": return "🇺🇸 English"
        default:   return "🌐 \(Locale.current.localizedString(forLanguageCode: code) ?? code)"
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(viewState.theme.accent.color.opacity(0.15))
                .foregroundStyle(viewState.theme.accent.color)
                .clipShape(Circle())
            Text(LocalizedStringKey(text))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettings()
    }
    .applyPreviewModifiers(withState: AppViewState.preview())
}

