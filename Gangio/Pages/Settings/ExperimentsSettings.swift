//
//  ExperimentsSettings.swift
//  Gangio
//
//  Created by Angelo on 2024-02-10.
//

import SwiftUI

struct ExperimentsSettings: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Info Banner
                HStack(spacing: 12) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.mint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Experimental Features")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                        Text("These features are still in development and may not work as expected.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                }
                .padding(16)
                .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                // Experiments
                SettingsSectionView(title: "Rendering") {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "text.badge.checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Markdown")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                            Text("Enhanced markdown rendering for messages")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: $viewState.userSettingsStore.store.experiments.customMarkdown)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Experiments")
        .navigationBarTitleDisplayMode(.inline)
        .background(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96))
        .toolbarBackground(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    ExperimentsSettings()
}
