//
//  SessionsSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct SessionsSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @State var sessions: [Session] = []
    @State var isLoading = true
    
    func deleteSession(session: Session) {
        Task {
            let _ = try? await viewState.http.deleteSession(session: session.id).get()
            withAnimation { sessions = sessions.filter({ $0.id != session.id }) }
        }
    }

    private var bgColor: Color {
        viewState.theme.background.color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading sessions...")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    let currentSession = sessions.first(where: { $0.id == viewState.currentSessionId })
                    let otherSessions = sessions.filter({ $0.id != viewState.currentSessionId }).sorted(by: { $0.id > $1.id })

                    // Current Device
                    if let session = currentSession {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("THIS DEVICE")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            HStack(spacing: 14) {
                                sessionIcon(for: session.name)
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .frame(width: 44, height: 44)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(10)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    
                                    let created = createdAt(id: session.id)
                                    let days = Calendar.current.dateComponents([.day], from: created, to: Date.now).day ?? 0
                                    Text(days == 0 ? "Active now" : "Created \(days) day(s) ago")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                
                                Spacer()
                                
                                Text("Active")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(6)
                            }
                            .padding(16)
                            .background(colorScheme == .dark ? Color(white: 0.12) : .white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        }
                    }

                    // Other Sessions
                    if !otherSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("OTHER SESSIONS (\(otherSessions.count))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(Array(otherSessions.enumerated()), id: \.element.id) { index, session in
                                    if index > 0 { Divider().padding(.leading, 70) }
                                    
                                    HStack(spacing: 14) {
                                        sessionIcon(for: session.name)
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                            .frame(width: 40, height: 40)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(10)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(session.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                            
                                            let created = createdAt(id: session.id)
                                            let days = Calendar.current.dateComponents([.day], from: created, to: Date.now).day ?? 0
                                            Text(days == 0 ? "Created today" : "Created \(days) day(s) ago")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { deleteSession(session: session) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(colorScheme == .dark ? Color(white: 0.12) : .white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        }
                    } else if currentSession != nil {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.green.opacity(0.5))
                            Text("No other active sessions")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(bgColor)
        .task {
            sessions = (try? await viewState.http.fetchSessions().get()) ?? []
            isLoading = false
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    func sessionIcon(for name: String) -> Image {
        let lower = name.lowercased()
        if lower.contains("ios") { return Image(systemName: "iphone") }
        if lower.contains("android") { return Image(systemName: "phone") }
        if lower.contains("safari") { return Image(systemName: "safari") }
        if lower.contains("chrome") || lower.contains("brave") { return Image(systemName: "globe") }
        if lower.contains("firefox") { return Image(systemName: "flame") }
        if lower.contains("mac") { return Image(systemName: "laptopcomputer") }
        if lower.contains("windows") { return Image(systemName: "desktopcomputer") }
        if lower.contains("linux") { return Image(systemName: "terminal") }
        return Image(systemName: "desktopcomputer")
    }
}
