//
//  VoiceChannelView.swift
//  Gangio
//
//  Created by benyigit on 25/04/2026.
//

import Foundation
import SwiftUI
import LiveKit
import Types
import ActivityKit
import AVKit
import LiveKitComponents

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
    @State var screenSharing: Bool = false
    @State var cameraEnabled: Bool = false
    @State var inCall: Bool = false
    @State var updater: Bool = false
    
    @MainActor
    func connect() async {
        let node = viewState.apiInfo!.features.livekit.nodes.first!
        
        let token = try! await viewState.http.joinVoiceChannel(channel: channel.id, node: node.name).get()
        let dele = VoiceChannelDelegate(updater: $updater)
        let room = Room(delegate: dele, connectOptions: ConnectOptions(autoSubscribe: true))
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try? session.setActive(true)
        
        try! await room.connect(url: node.public_url, token: token.token)
        
        viewState.currentVoiceChannel = channel.id
        viewState.currentVoice = room
        
//        let pfp = URL(string: viewState.currentUser!.avatar != nil ? viewState.formatUrl(with: viewState.currentUser!.avatar!) : "\(viewState.http.baseURL)/users/\(viewState.currentUser!.id)/default_avatar")!;
        
        //        activity = try! Activity.request(
        //            attributes: VoiceWidgetAttributes(
        //                us: viewState.currentUser!,
        //                pfp: pfp,
        //                channel: channel,
        //                channelName: channel.getName(viewState)
        //            ),
        //            content: .init(state: VoiceWidgetAttributes.ContentState(currentlySpeaking: [], weSpeaking: false), staleDate: nil)
        //        )
    }
    
    @MainActor
    func disconnect() async {
        if let room = viewState.currentVoice {
            viewState.currentVoice = nil
            viewState.currentVoiceChannel = nil

            await room.disconnect()
        }
    }
    
    func partipants(room: Room) -> [(Participant, UserMaybeMember)] {
        return room.allParticipants.values
            .compactMap({ participant in
                if let identity = participant.identity?.stringValue {
                    if let user = viewState.users[identity] {
                        return (participant, user)
                    } else if let metadata = participant.metadata?.data(using: .utf8), let user = try? JSONDecoder().decode(User.self, from: metadata) {
                        DispatchQueue.main.async {
                            if viewState.users[identity] == nil {
                                viewState.users[identity] = user
                            }
                            if viewState.users[user.id] == nil {
                                viewState.users[user.id] = user
                            }
                        }
                        
                        return (participant, user)
                    } else {
                        return nil
                    }
                }
                
                return nil
            })
            .map({ (p, user) in
                let member = server.flatMap { server in
                    if let member = viewState.members[server.id]?[user.id] {
                        return member as Member?
                    } else {
                        DispatchQueue.main.async {
                            if viewState.members[server.id] == nil {
                                viewState.members[server.id] = [:]
                            }
                        }
                        Task {
                            if let member = try? await viewState.http.fetchMember(server: server.id, member: user.id).get() {
                                await MainActor.run {
                                    viewState.members[server.id]?[user.id] = member
                                }
                            }
                        }
                        
                        return nil
                    }
                }
                
                return (p, UserMaybeMember(user: user, member: member))
            })
            .sorted(by: { p1, p2 in
                if p1.0 is LocalParticipant { return true }
                if p2.0 is LocalParticipant { return false }
                return (p1.0.joinedAt ?? Date()) < (p2.0.joinedAt ?? Date())
            })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PageToolbar(toggleSidebar: toggleSidebar) {
                NavigationLink(value: NavigationDestination.channel_info(channel.id)) {
                    ChannelIcon(channel: channel)
                    Image(systemName: "chevron.right")
                        .frame(height: 4)
                }
            } trailing: {
                Button {
                    inCall.toggle()
                } label: {
                    Text(inCall ? "Leave" : "Join")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(inCall ? viewState.theme.error.color : Color.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            
            VStack {
                ScrollView {
                    if let room = viewState.currentVoice {
                        RoomScope(room: room) {
                            ForEach(partipants(room: room), id: \.1.id) { (participant, user) in
                                let title = user.member?.nickname ?? user.user.display_name ?? user.user.username
                                
                                ForEach(participant.trackPublications.values.filter({ $0.kind == .video })) { track in
                                    VoiceChannelBox(title: title) {
                                        let _ = print(track.source, track.kind, track.isSubscribed)
                                        if track is LocalTrackPublication || track.isSubscribed {
                                            SwiftUIVideoView(track.track as! VideoTrack, layoutMode: .fit)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else if let remoteTrack = track as? RemoteTrackPublication {
                                            ZStack {
                                                viewState.theme.background3
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button {
                                                    Task {
                                                        try! await remoteTrack.set(subscribed: true)
                                                    }
                                                } label: {
                                                    Text("Watch")
                                                        .padding(12)
                                                        .background(Capsule().fill(viewState.theme.background2))
                                                }
                                            }
                                        }
                                    } overlay: {
                                        if let remoteTrack = track as? RemoteTrackPublication, remoteTrack.isSubscribed {
                                            Button {
                                                Task {
                                                    try! await remoteTrack.set(subscribed: false)
                                                }
                                            } label: {
                                                Text("Disconnect")
                                                    .padding(8)
                                                    .background(RoundedRectangle(cornerRadius: 8).fill(viewState.theme.error))
                                                    .transition(.opacity)
                                            }
                                            
                                        }
                                    }
                                }
                                
                                VoiceChannelBox(title: title) {
                                    AppAvatar(user: user.user, member: user.member, width: 48, height: 48)
                                } trailing: {
                                    if !participant.audioTracks.contains { track in
                                        track.source == .microphone && track.kind == .audio && !track.isMuted
                                    } {
                                        Image(systemName: "mic.slash.fill")
                                            .resizable()
                                            .scaledToFit()
                                        .frame(width: 16, height: 16)
                                    }
                                }
                                .addBorder(participant.isSpeaking ? Color.green : Color.clear, width: 1, cornerRadius: 8)
                            }
                        }
                    } else {
                        HStack(alignment: .center) {
                            VStack(alignment: .center) {
                                Text("Not Connected")
                                    .font(.title)
                                Text("Click the join button to connect")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .contentMargins(.top, 16, for: .scrollContent)
                
                //Spacer()
                
                HStack(spacing: 12) {
                    Group {
                        Button {
                            Task {
                                if inCall, await AVAudioApplication.requestRecordPermission() {
                                    unmuted.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: unmuted ? "mic.fill" : "mic.slash.fill")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        Button { if inCall { screenSharing.toggle() } } label: {
                            Image(systemName: "desktopcomputer")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        Button {
                            Task {
                                if inCall, await AVCaptureDevice.requestAccess(for: .video) {
                                    cameraEnabled.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: cameraEnabled ? "video.fill" : "video.slash.fill")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        // Removed Leave/Join call button from here as it's now in the header
                        
                        Button {
                            withAnimation {
                                viewState.currentChannel = .force_textchannel(channel.id)
                            }
                        } label: {
                            Image(systemName: "bubble.fill")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        Button { if inCall { defeaned.toggle() } } label: {
                            Image(systemName: defeaned ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                .frame(width: 16, height: 16)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            
                        }
                    }
                    .buttonBorderShape(.capsule)
                    .background(viewState.theme.accent)
                    .clipShape(.capsule)
                }
            }
            .padding([.horizontal, .bottom], 16)
        }
        .background(viewState.theme.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: inCall, { _, inCall in
            if inCall && viewState.currentVoiceChannel == channel.id {
                return
            }
            
            if inCall {
                Task {
                    await connect()
                }
            } else {
                Task {
                    await disconnect()
                }
            }
        })
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
        .onChange(of: updater, { _, _ in })
        .task {
            // resync state when view is reopened
            if viewState.currentVoiceChannel == channel.id {
                inCall = true
                if let room = viewState.currentVoice {
                    room.add(delegate: VoiceChannelDelegate(updater: $updater))
                    self.updater.toggle() // Force an immediate refresh
                }
            }
        }
    }
}

class VoiceChannelDelegate: RoomDelegate {
    @Binding var updater: Bool
    
    init(updater: Binding<Bool>) {
        self._updater = updater
    }
    func roomDidConnect(_ room: Room) {
        print(room)
    }
    
    func roomDidReconnect(_ room: Room) {
        print("reconnected")
    }
    
    func roomIsReconnecting(_ room: Room) {
        print("reconnecting")
    }
    
    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        print(error)
    }
    
    func room(_ room: Room, trackPublication: TrackPublication, didUpdateE2EEState state: E2EEState) {
        print("track publication \(trackPublication.kind), \(trackPublication.source)")
        print(trackPublication.track)
        
        self.updater.toggle()
    }
    
    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        self.updater.toggle()
    }
    
    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        self.updater.toggle()
    }
    
    func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        print("local \(publication.kind), \(publication.source)")
        print(publication.track)
        
        self.updater.toggle()
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        print("remote \(publication.kind), \(publication.source)")
        print(publication.track)
        // Auto-subscription will handle this now
        
        self.updater.toggle()
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

