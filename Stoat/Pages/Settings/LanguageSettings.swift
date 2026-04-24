//
//  LanguageSettings.swift
//  Revolt
//

import Foundation
import SwiftUI

struct LanguageSettings: View {
    @Environment(\.locale) var systemLocale: Locale
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewState: ViewState
    @State var searchText = ""
    @State var showRestartBanner = false

    // Popular languages with display names + ISO codes
    private let popularLanguages: [(String, String)] = [
        ("English", "en"),
        ("Türkçe", "tr"),
        ("Deutsch", "de"),
        ("Français", "fr"),
        ("Español", "es"),
        ("Italiano", "it"),
        ("Português", "pt"),
        ("Русский", "ru"),
        ("日本語", "ja"),
        ("한국어", "ko"),
        ("中文 (简体)", "zh-Hans"),
        ("中文 (繁體)", "zh-Hant"),
        ("العربية", "ar"),
        ("Nederlands", "nl"),
        ("Polski", "pl"),
        ("Svenska", "sv"),
        ("Norsk", "no"),
        ("Dansk", "da"),
        ("Suomi", "fi"),
        ("Ελληνικά", "el"),
        ("Čeština", "cs"),
        ("Magyar", "hu"),
        ("Română", "ro"),
        ("Українська", "uk"),
    ]

    var filteredLanguages: [(String, String)] {
        if searchText.isEmpty { return popularLanguages }
        return popularLanguages.filter {
            $0.0.localizedCaseInsensitiveContains(searchText) ||
            $0.1.localizedCaseInsensitiveContains(searchText)
        }
    }

    var currentLangCode: String? {
        viewState.currentLocale?.language.languageCode?.identifier
            ?? viewState.currentLocale.map { $0.identifier }
    }

    var isDark: Bool { colorScheme == .dark }
    var bg: Color { isDark ? Color(white: 0.07) : Color(white: 0.95) }
    var card: Color { isDark ? Color(white: 0.12) : Color.white }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                restartBanner
                searchBarSection
                automaticRow
                languageList
            }
            .padding(.top, 12)
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var restartBanner: some View {
        if showRestartBanner {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restart Required")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Close and reopen the app for the language to fully apply.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search language...", text: $searchText)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(11)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var automaticRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    viewState.currentLocale = nil
                    showRestartBanner = true
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    Text("Automatic (System)")
                        .font(.system(size: 15))
                        .foregroundStyle(isDark ? .white : .black)
                    Spacer()
                    if viewState.currentLocale == nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var languageList: some View {
        VStack(spacing: 0) {
            let filtered = filteredLanguages
            ForEach(Array(filtered.enumerated()), id: \.offset) { index, lang in
                let (name, code) = lang
                let isSelected = currentLangCode == code

                Button {
                    withAnimation {
                        viewState.currentLocale = Locale(identifier: code)
                        showRestartBanner = true
                    }
                } label: {
                    HStack(spacing: 14) {
                        Text(flagEmoji(for: code))
                            .font(.system(size: 22))
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? viewState.theme.accent.color : (isDark ? .white : .black))
                            Text(code.uppercased())
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(viewState.theme.accent.color)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if index < filtered.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    /// Returns a flag emoji for a language code. Maps to the most common country.
    func flagEmoji(for code: String) -> String {
        let map: [String: String] = [
            "en": "🇺🇸", "tr": "🇹🇷", "de": "🇩🇪", "fr": "🇫🇷",
            "es": "🇪🇸", "it": "🇮🇹", "pt": "🇵🇹", "ru": "🇷🇺",
            "ja": "🇯🇵", "ko": "🇰🇷", "zh-Hans": "🇨🇳", "zh-Hant": "🇹🇼",
            "ar": "🇸🇦", "nl": "🇳🇱", "pl": "🇵🇱", "sv": "🇸🇪",
            "no": "🇳🇴", "da": "🇩🇰", "fi": "🇫🇮", "el": "🇬🇷",
            "cs": "🇨🇿", "hu": "🇭🇺", "ro": "🇷🇴", "uk": "🇺🇦",
        ]
        return map[code] ?? "🌐"
    }
}

#Preview {
    NavigationStack {
        LanguageSettings()
    }
    .applyPreviewModifiers(withState: ViewState.preview())
}
