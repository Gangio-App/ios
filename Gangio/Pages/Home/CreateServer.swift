//
//  CreateServer.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import PhotosUI
import Gangio

enum ServerType: String, CaseIterable {
    case community = "Community"
    case gaming = "Gaming"
    case music = "Music"
    case education = "Education"
    case science = "Science"
    case technology = "Technology"
    case art = "Art"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .community: return "person.3.fill"
        case .gaming: return "gamecontroller.fill"
        case .music: return "music.note"
        case .education: return "book.fill"
        case .science: return "flask.fill"
        case .technology: return "cpu"
        case .art: return "paintbrush.fill"
        case .other: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .community: return .blue
        case .gaming: return .purple
        case .music: return .pink
        case .education: return .green
        case .science: return .cyan
        case .technology: return .orange
        case .art: return .red
        case .other: return .gray
        }
    }
}

struct CreateServer: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedType: ServerType = .community
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedPhotoData: Data? = nil
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    @State private var currentStep: Int = 1
    
    private var isDark: Bool { colorScheme == .dark }
    private var bg: Color { isDark ? Color(white: 0.07) : Color(white: 0.95) }
    private var card: Color { isDark ? Color(white: 0.13) : Color.white }
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            
            if currentStep == 1 {
                serverTypeSelection
            } else if currentStep == 2 {
                serverDetails
            }
        }
        .navigationTitle(currentStep == 1 ? "Create a Server" : "Customize Your Server")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedPhotoData = data
                }
            }
        }
    }
    
    private var serverTypeSelection: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    
                    Text("Create a Server")
                        .font(.title.bold())
                    
                    Text("Your server is where you and your friends hang out. Make yours and start talking.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    ForEach(ServerType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedType = type
                                currentStep = 2
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(type.color)
                                    .frame(width: 44, height: 44)
                                    .background(type.color.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(isDark ? .white : .black)
                                    
                                    Text("For \(type.rawValue.lowercased()) enthusiasts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var serverDetails: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Customize Your Server")
                        .font(.title.bold())
                    
                    Text("Give your new server a personality with a name and an icon. You can always change it later.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    // Avatar selection
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: selectedType.icon)
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white)
                                        .frame(width: 80, height: 80)
                                        .background(selectedType.color)
                                        .clipShape(Circle())
                                }
                                
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 2))
                                    .foregroundStyle(.blue.opacity(0.5))
                                    .frame(width: 88, height: 88)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Text("SERVER ICON")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Server name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVER NAME")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("My Awesome Server", text: $name)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(isDark ? Color(white: 0.1) : Color(white: 0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION (OPTIONAL)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("Tell us about your server...", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(isDark ? Color(white: 0.1) : Color(white: 0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }
                    
                    // Create button. Guard against rapid double-taps by flipping
                    // `isCreating` synchronously on the button action before any
                    // async work begins, so subsequent taps are ignored.
                    Button {
                        guard canCreate, !isCreating else { return }
                        isCreating = true
                        Task { await createServer() }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Server")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canCreate && !isCreating ? .blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!canCreate || isCreating)
                    .padding(.top, 8)
                }
                .padding(16)
            }
        }
    }
    
    @MainActor
    private func createServer() async {
        // `isCreating` is set to true synchronously by the Button action before
        // this function is invoked. We just guarantee it's reset on exit.
        defer { isCreating = false }
        errorMessage = nil
        
        let serverName = name.trimmingCharacters(in: .whitespaces)
        guard !serverName.isEmpty else {
            errorMessage = "Server name is required"
            return
        }
        
        var icon: String? = nil
        if let photoData = selectedPhotoData {
            let uploadResult = await viewState.http.uploadFile(data: photoData, name: "avatar.png", category: .icon)
            if case .success(let response) = uploadResult {
                icon = response.id
            }
        }
        
        let payload = CreateServerPayload(
            name: serverName,
            description: description.isEmpty ? nil : description,
            icon: icon
        )
        
        let result = await viewState.http.createServer(payload: payload)
        
        switch result {
        case .success(let server):
            // Wait a moment for the backend to link the icon and process the server fully
            try? await Task.sleep(for: .seconds(1))
            
            // Fetch the full server and its channels to ensure everything is in sync
            let fullServerRes = await viewState.http.fetchServer(server: server.id)
            if case .success(let fullServer) = fullServerRes {
                viewState.servers[fullServer.id] = fullServer
                // Also fetch channels for this server
                let channelsRes = await viewState.http.fetchChannels(server: server.id)
                if case .success(let channels) = channelsRes {
                    for channel in channels {
                        viewState.channels[channel.id] = channel
                    }
                }
                viewState.currentChannel = .channel(fullServer.channels.first ?? "")
            } else {
                viewState.servers[server.id] = server
                viewState.currentChannel = .channel(server.channels.first ?? "")
            }
            dismiss()
        case .failure(let error):
            // Check if server was actually created despite error (e.g. decoding failure or timeout)
            // Try to find a server with the same name and owner that was recently created
            if let existing = viewState.servers.values.first(where: { $0.name == serverName && $0.owner == viewState.currentUser?.id }) {
                // Refresh it to be sure
                let fullServerRes = await viewState.http.fetchServer(server: existing.id)
                if case .success(let fullServer) = fullServerRes {
                    viewState.servers[fullServer.id] = fullServer
                    viewState.currentChannel = .channel(fullServer.channels.first ?? "")
                }
                dismiss()
            } else {
                errorMessage = "Failed to create server. Please try again."
                print("Server creation error: \(error)")
            }
        }
    }
}
