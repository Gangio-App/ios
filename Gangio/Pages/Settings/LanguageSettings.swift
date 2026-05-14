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
    @State private var showRestartAlert = false

    private var isDark: Bool { colorScheme == .dark }
    private var bg: Color { isDark ? Color(white: 0.07) : Color(white: 0.95) }
    private var card: Color { isDark ? Color(white: 0.12) : Color.white }

    private let availableLanguages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("tr", "Türkçe", "🇹🇷")
    ]

    private var currentCode: String {
        viewState.currentLocale?.language.languageCode?.identifier
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 14) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(viewState.theme.accent.color)

                        Text("Language")
                            .font(.title2.bold())

                        Text("Choose your preferred language. The app will restart to apply changes.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Language picker
                    VStack(spacing: 0) {
                        ForEach(Array(availableLanguages.enumerated()), id: \.offset) { idx, lang in
                            Button {
                                selectLanguage(code: lang.code)
                            } label: {
                                HStack(spacing: 14) {
                                    Text(lang.flag)
                                        .font(.system(size: 28))
                                    Text(lang.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(isDark ? .white : .black)
                                    Spacer()
                                    if currentCode == lang.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(viewState.theme.accent.color)
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if idx < availableLanguages.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Language Changed", isPresented: $showRestartAlert) {
            Button("OK") {}
        } message: {
            Text("The app's language has been switched. Some screens may need to be re-opened to update.")
        }
    }
    
    private func selectLanguage(code: String) {
        // Bundle.setInAppLanguage is called inside `currentLocale.didSet`.
        viewState.currentLocale = Locale(identifier: code)
        showRestartAlert = true
    }
}

#Preview {
    NavigationStack {
        LanguageSettings()
    }
    .applyPreviewModifiers(withState: AppViewState.preview())
}

