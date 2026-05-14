//
//  VoiceChannelView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import LiveKit
import Types
import ActivityKit
import AVKit
import LiveKitComponents
import ReplayKit

private func downloadImage(from url: URL) async throws -> URL? {
    guard var destination = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.chat.gangio.app")
    else { return nil }
    
    destination = destination.appendingPathComponent(url.lastPathComponent)
    
    guard !FileManager.default.fileExists(atPath: destination.path()) else {
        return destination
    }
    
    let (source, _) = try await URLSession.shared.download(from: url)
    try FileManager.default.moveItem(at: source, to: destination)
    return destination
}


struct TokenResponse: Decodable {
    var token: String
}

struct VoiceChannelView: View {
    @EnvironmentObject var viewState: AppViewState
    
    var channel: Channel
    var server: Server?
    
    var toggleSidebar: () -> ()
    
    @Binding var disableScroll: Bool
    @Binding var disableSidebar: Bool

    @State var unmuted: Bool = false
    @State var defeaned: Bool = false
    @State var isFrontCamera: Bool = true
    @State var screenSharing: Bool = false
    @State var cameraEnabled: Bool = false
    var isConnected: Bool {
        viewState.currentVoiceChannel == channel.id && viewState.currentVoice != nil
    }

    func partipants(room: Room) -> [(Participant, UserMaybeMember)] {
        let allParticipants = room.allParticipants.values
        let usersWithParticipants: [(Participant, Types.User)] = allParticipants.compactMap { (participant: Participant) -> (Participant, Types.User)? in
            guard let identity = participant.identity?.stringValue else { return nil }
            
            if let user = viewState.users[identity] {
                return (participant, user)
            } else if let metadata = participant.metadata?.data(using: .utf8), 
                      let user = try? JSONDecoder().decode(User.self, from: metadata) {
                DispatchQueue.main.async {
                    if viewState.users[identity] == nil {
                        viewState.users[identity] = user
                    }
                    if viewState.users[user.id] == nil {
                        viewState.users[user.id] = user
                    }
                }
                return (participant, user)
            }
            return nil
        }
        
        let results: [(Participant, UserMaybeMember)] = usersWithParticipants.map { (p, user) in
            var member: Member? = nil
            if let server = self.server {
                if let existingMember = viewState.members[server.id]?[user.id] {
                    member = existingMember
                } else {
                    DispatchQueue.main.async {
                        if viewState.members[server.id] == nil {
                            viewState.members[server.id] = [:]
                        }
                    }
                    Task {
                        if let fetchedMember = try? await viewState.http.fetchMember(server: server.id, member: user.id).get() {
                            await MainActor.run {
                                viewState.members[server.id]?[user.id] = fetchedMember
                            }
                        }
                    }
                }
            }
            
            return (p, UserMaybeMember(user: user, member: member))
        }
        
        return results.sorted { p1, p2 in
            if p1.0 is LocalParticipant { return true }
            if p2.0 is LocalParticipant { return false }
            return (p1.0.joinedAt ?? Date()) < (p2.0.joinedAt ?? Date())
        }
    }
    
    @ViewBuilder
    private var notConnectedView: some View {
        let participants: [(Types.User, Member?)] = {
            guard let voiceState = viewState.voiceStates[channel.id] else { return [] }
            return voiceState.values.compactMap { participant in
                guard let user = viewState.users[participant.id] else { return nil }
                let member = server.flatMap { viewState.members[$0.id]?[participant.id] }
                return (user, member)
            }
        }()
        
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(viewState.theme.accent.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "waveform")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(viewState.theme.accent.color)
            }
            
            VStack(spacing: 8) {
                Text("Ready to talk?")
                    .font(.title2.bold())
                Text(channel.name ?? "Voice Channel")
                    .foregroundStyle(.secondary)
            }
            
            // Show avatars of users currently in the channel
            if !participants.isEmpty {
                VStack(spacing: 8) {
                    HStack(spacing: -8) {
                        ForEach(Array(participants.prefix(8).enumerated()), id: \.element.0.id) { idx, pair in
                            AppAvatar(user: pair.0, member: pair.1, width: 36, height: 36)
                                .overlay(Circle().stroke(viewState.theme.background.color, lineWidth: 2))
                                .zIndex(Double(8 - idx))
                        }
                        if participants.count > 8 {
                            Circle()
                                .fill(viewState.theme.background3.color)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(viewState.theme.background.color, lineWidth: 2))
                                .overlay(
                                    Text("+\(participants.count - 8)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(viewState.theme.foreground.color)
                                )
                        }
                    }
                    Text("\(participants.count) in voice")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                Task {
                    await viewState.joinVoice(channelId: channel.id)
                }
            } label: {
                Text("Join Voice")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(viewState.theme.accent.color)
                    .clipShape(Capsule())
                    .shadow(color: viewState.theme.accent.color.opacity(0.3), radius: 10, y: 5)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var inCallView: some View {
        if let room = viewState.currentVoice {
            let allParticipants = partipants(room: room)
            
            VStack(spacing: 0) {
                // Voice status banner
                voiceStatusBanner(participantCount: allParticipants.count)
                
                // Main scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Video/Screen share tiles at the top
                        ForEach(allParticipants, id: \.1.id) { (participant, user) in
                            let videoPub = getActiveVideoPublication(for: participant)
                            let screenPub = getActiveScreenShare(for: participant)
                            
                            if let pub = screenPub {
                                videoTile(participant: participant, publication: pub, user: user)
                            }
                            
                            if let pub = videoPub {
                                videoTile(participant: participant, publication: pub, user: user)
                            }
                        }
                        
                        // Participant grid - 2 columns
                        let columns = [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(allParticipants, id: \.1.id) { (participant, user) in
                                participantCard(participant: participant, user: user)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        }
    }
    
    @ViewBuilder
    private func voiceStatusBanner(participantCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewState.theme.accent.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Connected")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground.color)
                
                Text(channel.name ?? "Voice Channel")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(participantCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Image(systemName: "person.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(viewState.theme.background2.color)
    }
    
    private func getActiveScreenShare(for participant: Participant) -> TrackPublication? {
        return participant.trackPublications.values.first { pub -> Bool in
            guard pub.kind == .video else { return false }
            guard let track = pub.track else { return false }
            guard track.source == .screenShareVideo else { return false }
            if pub is LocalTrackPublication { return true }
            return pub.isSubscribed
        }
    }
    
    private func getActiveVideoPublication(for participant: Participant) -> TrackPublication? {
        let videoPublication = participant.trackPublications.values.first { pub -> Bool in
            guard pub.kind == .video else { return false }
            guard let track = pub.track else { return false }
            guard track.source == .camera else { return false }
            guard !pub.isMuted else { return false }
            
            if pub is LocalTrackPublication { return true }
            return pub.isSubscribed
        }
        
        if participant is LocalParticipant {
            return cameraEnabled ? videoPublication : nil
        }
        return videoPublication
    }
    
    @ViewBuilder
    private func videoTile(participant: Participant, publication: TrackPublication, user: UserMaybeMember) -> some View {
        let title = user.member?.nickname ?? user.user.display_name ?? user.user.username
        let isScreenShare = publication.track?.source == .screenShareVideo
        
        ZStack(alignment: .bottomLeading) {
            if publication is LocalTrackPublication || publication.isSubscribed {
                SwiftUIVideoView(publication.track as! VideoTrack, layoutMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: isScreenShare ? 240 : 200)
                    .clipped()
                    .onTapGesture {
                        withAnimation {
                            viewState.selectedTrack = publication.track as? VideoTrack
                        }
                    }
            } else if let remoteTrack = publication as? RemoteTrackPublication {
                Button {
                    Task { try? await remoteTrack.set(subscribed: true) }
                } label: {
                    ZStack {
                        viewState.theme.background3.color
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22))
                            Text("Watch Stream")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(viewState.theme.accent.color.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Name + type label
            HStack(spacing: 6) {
                if isScreenShare {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            )
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    @ViewBuilder
    private func participantCard(participant: Participant, user: UserMaybeMember) -> some View {
        let title = user.member?.nickname ?? user.user.display_name ?? user.user.username
        let isMuted = !participant.audioTracks.contains { track -> Bool in
            track.source == .microphone && track.kind == .audio && !track.isMuted
        }
        
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AppAvatar(user: user.user, member: user.member, width: 56, height: 56)
                
                if isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 4, y: 4)
                }
            }
            
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(viewState.theme.foreground.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(participant.isSpeaking ? Color.green : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.15), value: participant.isSpeaking)
        .contextMenu {
            participantContextMenu(participant: participant, user: user)
        }
    }
    
    @ViewBuilder
    private func participantContextMenu(participant: Participant, user: UserMaybeMember) -> some View {
        let isLocalUser = participant is LocalParticipant
        
        Button {
            viewState.openUserSheet(user: user.user, member: user.member)
        } label: {
            Label("View Profile", systemImage: "person.crop.circle")
        }
        
        if !isLocalUser {
            // Mute locally (subscribe/unsubscribe audio)
            Button {
                Task {
                    for track in participant.audioTracks {
                        if let remoteTrack = track as? RemoteTrackPublication {
                            try? await remoteTrack.set(subscribed: !remoteTrack.isSubscribed)
                        }
                    }
                }
            } label: {
                Label("Toggle Mute (Local)", systemImage: "speaker.slash.fill")
            }
            
            // Admin actions (require permissions)
            if let server = viewState.openServer,
               let currentUser = viewState.currentUser,
               let currentMember = viewState.openServerMember {
                let perms = resolveServerPermissions(user: currentUser, member: currentMember, server: server)
                
                if perms.contains(.kickMembers) {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewState.http.kickMember(server: server.id, user: user.user.id)
                        }
                    } label: {
                        Label("Kick from Server", systemImage: "person.fill.xmark")
                    }
                }
                
                if perms.contains(.banMembers) {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewState.http.banMember(server: server.id, user: user.user.id, reason: nil)
                        }
                    } label: {
                        Label("Ban from Server", systemImage: "hand.raised.slash.fill")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                // Camera
                VoiceActionButton(icon: cameraEnabled ? "video.fill" : "video.slash.fill", isActive: cameraEnabled) {
                    Task {
                        if await AVCaptureDevice.requestAccess(for: .video) {
                            cameraEnabled.toggle()
                        }
                    }
                }
                
                // Screen Share
                ZStack {
                    VoiceActionButton(icon: "rectangle.on.rectangle", isActive: screenSharing) {
                        screenSharing.toggle()
                    }
                    BroadcastPicker()
                        .frame(width: 44, height: 44)
                        .opacity(0.01)
                }
                
                if cameraEnabled {
                    VoiceActionButton(icon: "camera.rotate.fill", isActive: false) {
                        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
                        isFrontCamera.toggle()
                        Task {
                            guard let room = viewState.currentVoice else { return }
                            
                            // Try switching camera position on the existing capturer first;
                            // fall back to a full republish if anything goes wrong.
                            var switched = false
                            if let cameraPublication = room.localParticipant.videoTracks.first(where: { $0.source == .camera }) as? LocalTrackPublication,
                               let cameraTrack = cameraPublication.track as? LocalVideoTrack,
                               let cameraCapturer = cameraTrack.capturer as? CameraCapturer {
                                do {
                                    _ = try await cameraCapturer.switchCameraPosition()
                                    switched = true
                                } catch {
                                    print("[Gangio] switchCameraPosition failed: \(error)")
                                }
                            }
                            
                            if !switched {
                                // Republish camera with the new position.
                                try? await room.localParticipant.setCamera(enabled: false)
                                try? await room.localParticipant.setCamera(
                                    enabled: true,
                                    captureOptions: CameraCaptureOptions(position: newPosition)
                                )
                            }
                        }
                    }
                }
                
                // Mic
                VoiceActionButton(icon: unmuted ? "mic.fill" : "mic.slash.fill", isActive: unmuted) {
                    Task {
                        if await AVAudioApplication.requestRecordPermission() {
                            unmuted.toggle()
                        }
                    }
                }
                
                // Deafen
                VoiceActionButton(icon: defeaned ? "speaker.slash.fill" : "speaker.wave.3.fill", isActive: defeaned) {
                    defeaned.toggle()
                }
            }
            
            Spacer(minLength: 8)
            
            // Leave Call
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                Task {
                    await viewState.leaveVoice()
                }
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen opaque background that always extends past the home
            // indicator and into the safe areas, so the channel sidebar /
            // chat behind this view never bleeds through.
            viewState.theme.background.color
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                PageToolbar(toggleSidebar: toggleSidebar) {
                    NavigationLink(value: NavigationDestination.channel_info(channel.id)) {
                        ChannelIcon(channel: channel)
                        Image(systemName: "chevron.right")
                            .frame(height: 4)
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                } trailing: {
                    Button {
                        withAnimation {
                            viewState.currentChannel = .force_textchannel(channel.id)
                        }
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(viewState.theme.foreground.color)
                            .padding(8)
                            .background(viewState.theme.background2.color)
                            .clipShape(Circle())
                    }
                }
                
                ZStack(alignment: .bottom) {
                    if !isConnected {
                        notConnectedView
                    } else {
                        inCallView
                        actionBar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color.ignoresSafeArea())
        .onChange(of: unmuted, { @MainActor _, unmuted in
            if let room = viewState.currentVoice {
                Task {
                    try? await room.localParticipant.setMicrophone(enabled: unmuted)
                }
            }
        })
        .onChange(of: cameraEnabled, { @MainActor _, cameraEnabled in
            if let room = viewState.currentVoice {
                Task {
                    try? await room.localParticipant.setCamera(enabled: cameraEnabled)
                }
            }
        })
        .onChange(of: screenSharing, { @MainActor _, screenSharing in
            if let room = viewState.currentVoice {
                Task {
                    try? await room.localParticipant.setScreenShare(enabled: screenSharing)
                }
            }
        })
        .onChange(of: viewState.voiceUpdater, { _, _ in })
        .task {
            // Don't auto-join — user clicks "Join Voice" button.
            // Just sync UI state if already connected to this channel.
            if let room = viewState.currentVoice, viewState.currentVoiceChannel == channel.id {
                // Restore local track states from room
                let localParticipant = room.localParticipant
                unmuted = localParticipant.isMicrophoneEnabled()
                cameraEnabled = localParticipant.isCameraEnabled()
                screenSharing = localParticipant.isScreenShareEnabled()
            }
        }
    }
}



#Preview {
    let state = AppViewState.preview()
    
    VoiceChannelView(
        channel: state.channels["1"]!,
        toggleSidebar: {},
        disableScroll: .constant(false),
        disableSidebar: .constant(false)
    )
    .applyPreviewModifiers(withState: state)
}

struct VoiceActionButton: View {
    @EnvironmentObject var viewState: AppViewState
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isActive ? .white : viewState.theme.foreground.color)
                .frame(width: 46, height: 46)
                .background(isActive ? viewState.theme.accent.color : viewState.theme.background3.color)
                .clipShape(Circle())
        }
    }
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 46, height: 46))
        picker.preferredExtension = "chat.gangio.app.BroadcastExtension"
        picker.showsMicrophoneButton = false
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

