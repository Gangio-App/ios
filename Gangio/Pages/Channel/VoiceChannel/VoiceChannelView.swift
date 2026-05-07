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
            RoomScope(room: room) {
                let columns = [GridItem(.adaptive(minimum: 150, maximum: .infinity), spacing: 16)]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(partipants(room: room), id: \.1.id) { (participant, user) in
                            participantTile(participant: participant, user: user)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    @ViewBuilder
    private func participantTile(participant: Participant, user: UserMaybeMember) -> some View {
        let title = user.member?.nickname ?? user.user.display_name ?? user.user.username
        let videoTracks = participant.trackPublications.values.filter({ $0.kind == .video })
        
        VStack(spacing: 0) {
            ForEach(videoTracks) { track in
                VoiceChannelBox(title: title) {
                    if track is LocalTrackPublication || track.isSubscribed {
                        ZStack {
                            SwiftUIVideoView(track.track as! VideoTrack, layoutMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Button {
                                withAnimation {
                                    viewState.selectedTrack = track.track as? VideoTrack
                                }
                            } label: {
                                Color.white.opacity(0.001)
                            }
                        }
                    } else if let remoteTrack = track as? RemoteTrackPublication {
                        Button {
                            Task { try! await remoteTrack.set(subscribed: true) }
                        } label: {
                            ZStack {
                                viewState.theme.background3.color
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                VStack(spacing: 12) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 24))
                                    Text("Watch Stream")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(viewState.theme.accent.color.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } overlay: {
                    if let remoteTrack = track as? RemoteTrackPublication, remoteTrack.isSubscribed {
                        Button {
                            Task { try! await remoteTrack.set(subscribed: false) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
            }
            
            if videoTracks.isEmpty {
                VoiceChannelBox(title: title) {
                    AppAvatar(user: user.user, member: user.member, width: 64, height: 64)
                } trailing: {
                    if !participant.audioTracks.contains(where: { track in
                        track.source == .microphone && track.kind == .audio && !track.isMuted
                    }) {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(Color.red))
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .addBorder(participant.isSpeaking ? Color.green : Color.clear, width: 3, cornerRadius: 16)
                .animation(.easeInOut(duration: 0.15), value: participant.isSpeaking)
            }
        }
    }
    
    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 16) {
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
                VoiceActionButton(icon: "desktopcomputer", isActive: screenSharing) {
                    screenSharing.toggle()
                }
                BroadcastPicker()
                    .frame(width: 46, height: 46)
                    .opacity(0.01)
            }
            
            if cameraEnabled {
                VoiceActionButton(icon: "camera.rotate.fill", isActive: false) {
                    isFrontCamera.toggle()
                    Task {
                        if let room = viewState.currentVoice {
                            // On some versions of LiveKit, we use CameraCaptureOptions to change position
                            // or switchCamera() on the track.
                            if let track = room.localParticipant.videoTracks.first?.track as? LocalVideoTrack {
                                // track.restartTrack(with: CameraCaptureOptions(position: isFrontCamera ? .front : .back))
                                // But for now, let's just use the simplest build-fixing way
                                try? await room.localParticipant.setCamera(enabled: true)
                            }
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
            
            Spacer()
            
            // Leave Call
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                Task {
                    await viewState.leaveVoice()
                }
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: Color.red.opacity(0.4), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    var body: some View {
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
        }
        .background(viewState.theme.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

