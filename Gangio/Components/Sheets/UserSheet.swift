//
//  MemberSheet.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Flow
import Types
import ExyteGrid
import Gangio

enum Badges: Int, CaseIterable {
    case developer = 1
    case translator = 2
    case supporter = 4
    case responsible_disclosure = 8
    case founder = 16
    case moderation = 32
    case active_supporter = 64
    case paw = 128
    case early_adopter = 256
    case amog = 512
    case amorbus = 1024
}

struct UserSheetHeader: View {
    @EnvironmentObject var viewState: AppViewState
    var user: User
    var member: Member?
    var profile: Profile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let banner = profile.background {
                LazyImage(source: .file(banner), height: 150, clipTo: Rectangle())
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            } else {
                // Discord-style colored banner
                LinearGradient(
                    colors: [viewState.theme.accent.color, viewState.theme.accent.color.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 150)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            }
        }
    }
}

struct UserSheet: View {
    @EnvironmentObject var viewState: AppViewState
    
    var user: User
    var member: Member?
    
    @State var profile: Profile?
    @State var owner: User = .init(id: String(repeating: "0", count: 26), username: "Unknown", discriminator: "0000")
    @State var mutualServers: [String] = []
    @State var mutualFriends: [String] = []
    @State var showReportSheet = false
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    func getRoleColour(role: Role) -> AnyShapeStyle {
        if let colour = role.colour {
            return parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: colour)
        } else {
            return AnyShapeStyle(viewState.theme.foreground)
        }
    }
    
    var body: some View {
        ScrollView {
            if let profile = profile {
                VStack(spacing: 0) {
                    // ── Banner ──
                    ZStack(alignment: .top) {
                        UserSheetHeader(user: user, member: member, profile: profile)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)
                            .padding(.top, 32)
                        
                        // Top Right "+" button (Friend Request / Action)
                        HStack {
                            Spacer()
                            Button {
                                switch user.relationship ?? .None {
                                case .User:
                                    viewState.path.append(NavigationDestination.settings)
                                case .Friend:
                                    Task { await viewState.openDm(with: user.id) }
                                case .Incoming, .None:
                                    Task { await viewState.http.sendFriendRequest(username: user.username) }
                                case .Outgoing:
                                    Task { await viewState.http.removeFriend(user: user.id) }
                                case .Blocked, .BlockedOther, .Unknown:
                                    break
                                }
                            } label: {
                                Image(systemName: actionButtonIcon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.black.opacity(0.45)))
                            }
                            .padding(.trailing, 28)
                            .padding(.top, 44)
                        }
                    }
                    
                    // ── Avatar with Status Ring ──
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(statusColor(for: user.status?.presence ?? (user.online == true ? .Online : nil)))
                                .frame(width: 100, height: 100)
                            
                            Circle()
                                .fill(viewState.theme.background.color)
                                .frame(width: 92, height: 92)
                            
                            AppAvatar(user: user, width: 86, height: 86, withPresence: false)
                                .clipShape(Circle())
                        }
                        
                        // Status indicator dot
                        Circle()
                            .fill(statusColor(for: user.status?.presence ?? (user.online == true ? .Online : nil)))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(viewState.theme.background.color, lineWidth: 3))
                            .offset(x: -6, y: -6)
                    }
                    .frame(width: 100, height: 100)
                    .offset(y: -50)
                    .padding(.bottom, -50)
                    
                    // ── Display Name ──
                    VStack(spacing: 6) {
                        if let display_name = user.display_name, !display_name.isEmpty {
                            Text(display_name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(viewState.theme.foreground.color)
                        } else {
                            Text(user.username)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(viewState.theme.foreground.color)
                        }
                        
                        Text("@\(user.username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(viewState.theme.foreground2.color)
                    }
                    .padding(.top, 12)
                    
                    // ── Bio ──
                    if let bio = profile.content, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(viewState.theme.foreground2.color)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                    }
                    
                    // ── Badges ──
                    if let badges = user.badges, badges > 0 {
                        HStack(spacing: 8) {
                            ForEach(Badges.allCases, id: \.self) { value in
                                if badges & (value.rawValue << 0) != 0 {
                                    Image(String(describing: value))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                    
                    // ── Roles ──
                    if let member = member, let server = viewState.servers[member.id.server], let roles = member.roles, !roles.isEmpty {
                        HFlow(spacing: 6) {
                            ForEach(roles, id: \.self) { roleId in
                                if let role = server.roles?[roleId] {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .foregroundStyle(getRoleColour(role: role))
                                            .frame(width: 10, height: 10)
                                        Text(role.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(viewState.theme.foreground.color)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(viewState.theme.background2.color)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }
                    
                    // ── Cards Section ──
                    VStack(spacing: 10) {
                        // Mutual Servers
                        if !mutualServers.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "server.rack")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                    Text("Mutual Servers")
                                        .font(.system(size: 13, weight: .bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                    Spacer()
                                }
                                
                                ForEach(mutualServers.prefix(4), id: \.self) { serverId in
                                    if let server = viewState.servers[serverId] {
                                        HStack(spacing: 12) {
                                            ServerIcon(server: server, height: 36, width: 36, clipTo: RoundedRectangle(cornerRadius: 8))
                                            Text(server.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(viewState.theme.foreground.color)
                                            Spacer()
                                        }
                                    }
                                }
                                
                                if mutualServers.count > 4 {
                                    Text("+ \(mutualServers.count - 4) more")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(viewState.theme.accent.color)
                                }
                            }
                            .padding(16)
                            .background(viewState.theme.background2.color)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Mutual Friends
                        if !mutualFriends.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                    Text("Mutual Friends")
                                        .font(.system(size: 13, weight: .bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                    Spacer()
                                }
                                
                                ForEach(mutualFriends.prefix(4), id: \.self) { friendId in
                                    if let friend = viewState.users[friendId] {
                                        HStack(spacing: 12) {
                                            AppAvatar(user: friend, width: 36, height: 36, withPresence: true)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(friend.display_name ?? friend.username)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(viewState.theme.foreground.color)
                                                Text("@\(friend.username)")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(viewState.theme.foreground3.color)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                
                                if mutualFriends.count > 4 {
                                    Text("+ \(mutualFriends.count - 4) more")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(viewState.theme.accent.color)
                                }
                            }
                            .padding(16)
                            .background(viewState.theme.background2.color)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Member Since
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(viewState.theme.foreground3.color)
                                Text("Member Since")
                                    .font(.system(size: 13, weight: .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(viewState.theme.foreground3.color)
                                Spacer()
                            }
                            
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gangio")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                    Text(createdAt(id: user.id), style: .date)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(viewState.theme.foreground.color)
                                }
                                
                                if let member = member {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Server")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(viewState.theme.foreground3.color)
                                        let f = ISO8601DateFormatter()
                                        let _ = f.formatOptions.insert(.withFractionalSeconds)
                                        Text(f.date(from: member.joined_at) ?? Date(), style: .date)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(viewState.theme.foreground.color)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(viewState.theme.background2.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // ── Bottom Three-Dot Menu ──
                    Menu {
                        Button {
                            copyText(text: user.id)
                        } label: {
                            Label("Copy ID", systemImage: "doc.on.doc")
                        }
                        
                        if user.relationship != .User {
                            Button {
                                Task {
                                    if case .success(let blockedUser) = await viewState.http.blockUser(user: user.id) {
                                        DispatchQueue.main.async { viewState.users[user.id] = blockedUser }
                                    }
                                }
                            } label: {
                                Label("Block", systemImage: "nosign")
                            }
                            
                            Button(role: .destructive) {
                                showReportSheet = true
                            } label: {
                                Label("Report", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(viewState.theme.foreground2.color)
                            .frame(width: 44, height: 44)
                            .background(viewState.theme.background2.color)
                            .clipShape(Circle())
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    ProgressView()
                        .tint(viewState.theme.accent.color)
                    Text("Loading profile...")
                        .font(.system(size: 14))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(viewState.theme.background.color)
        .presentationBackground(viewState.theme.background)
        .sheet(isPresented: $showReportSheet) {
            ReportUserSheetView(showSheet: $showReportSheet, user: user)
        }
        .task(id: user.id) {
            if let profile = user.profile {
                self.profile = profile
            } else {
                profile = try? await viewState.http.fetchProfile(user: user.id).get()
            }
        }
        .task(id: user.id) {
            if user.id != viewState.currentUser!.id,
               let mutuals = try? await viewState.http.fetchMutuals(user: user.id).get()
            {
                mutualServers = mutuals.servers
                mutualFriends = mutuals.users
            }
        }
        .id(user.id)
    }
    
    private var actionButtonIcon: String {
        switch user.relationship ?? .None {
        case .User: return "pencil"
        case .Friend: return "message.fill"
        case .Incoming, .None: return "plus"
        case .Outgoing: return "xmark"
        case .Blocked, .BlockedOther, .Unknown: return "nosign"
        }
    }
    
    private func statusColor(for presence: Presence?) -> Color {
        switch presence {
        case .Online: return .green
        case .Idle: return .orange
        case .Focus: return .purple
        case .Busy: return .red
        case .Invisible, .none, .some(.Unknown): return .gray
        }
    }
}

// MARK: - Profile Info Card Component
struct ProfileInfoCard<Content: View>: View {
    @EnvironmentObject var viewState: AppViewState
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground3.color)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground3.color)
                    .textCase(.uppercase)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct Badge: View {
    var badges: Int
    var filename: String
    var value: Int
    
    var body: some View {
        if badges & (value << 0) != 0 {
            Image(filename)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }
}

struct UserSheetPreview: PreviewProvider {
    @StateObject static var viewState: AppViewState = AppViewState.preview()
        
    static var previews: some View {
        Text("foo")
            .sheet(isPresented: .constant(true)) {
                UserSheet(user: viewState.users["0"]!, member: nil)
            }
            .applyPreviewModifiers(withState: viewState)
    }
}
struct ReportUserSheetView: View {
    @Binding var showSheet: Bool
    var user: User

    var body: some View {
        ReportSheet(target: .user(user))
    }
}
