//
//  About.swift
//  Gangio
//
//  Created by Angelo on 31/10/2023.
//

import Foundation
import SwiftUI

struct About: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Logo Card
                VStack(spacing: 16) {
                    Image("wide")
                        .resizable()
                        .if(colorScheme == .dark, content: { $0.colorInvert() })
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 36)
                        .padding(.top, 24)

                    Text("Gangio iOS")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                    Text("v\(Bundle.main.releaseVersionNumber ?? "?")")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
                        .cornerRadius(8)

                    Text("Brought to you with ❤️\nby the Gangio team.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)

                // Info Section
                SettingsSectionView(title: "Information") {
                    InfoRow(icon: "hammer.fill", iconColor: .orange, title: "Built with", value: "SwiftUI")
                    Divider().padding(.leading, 52)
                    InfoRow(icon: "swift", iconColor: .orange, title: "Language", value: "Swift")
                    Divider().padding(.leading, 52)
                    InfoRow(icon: "cpu", iconColor: .blue, title: "Platform", value: "iOS / iPadOS")
                }

                // Links Section
                SettingsSectionView(title: "Links") {
                    if let url = URL(string: "https://gangio.pro") {
                        Link(destination: url) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "globe")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                Text("Website")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96))
    }
}

// MARK: - Info Row (non-navigable)
struct InfoRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct About_Preview: PreviewProvider {
    static var previews: some View {
        About()
            .environmentObject(ViewState.preview())
    }
}
