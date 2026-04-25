//
//  Websocket.swift
//  Gangio
//
//  Created by Zomatree on 21/04/2023.
//

import Foundation
import Starscream
import Types
import AnyCodable

enum WsMessage {
    case authenticated
    case invalid_session
    case bulk(BulkEvent)
    case error(ErrorEvent)
    case logout
    case pong(PongEvent)
    case ready(ReadyEvent)
    case message(Message)
    case message_update(MessageUpdateEvent)
    case channel_start_typing(ChannelTyping)
    case channel_stop_typing(ChannelTyping)
    case message_delete(MessageDeleteEvent)
    case channel_ack(ChannelAckEvent)
    case voice_channel_join(VoiceChannelJoin)
    case voice_channel_leave(VoiceChannelLeave)
    case message_react(MessageReactEvent)
    case message_unreact(MessageReactEvent)
    case message_append(MessageAppend)
    case message_remove_reaction(MessageRemoveReaction)
    case bulk_message_delete(BulkMessageDelete)
    case channel_create(Channel)
    case channel_update(ChannelUpdate)
    case channel_delete(ChannelDelete)
    case channel_group_join(ChannelGroupJoin)
    case channel_group_leave(ChannelGroupLeave)
    case server_create(ServerCreate)
    case server_update(ServerUpdate)
    case server_delete(ServerDelete)
    case server_member_join(ServerMemberJoin)
    case server_member_update(ServerMemberUpdate)
    case server_member_leave(ServerMemberLeave)
    case server_role_update(ServerRoleUpdate)
    case server_role_delete(ServerRoleDelete)
    case user_update(UserUpdate)
    case user_relationship(UserRelationship)
    case user_settings_update(UserSettingsUpdate)
    case user_platform_wipe(UserPlatformWipe)
    case emoji_create(Emoji)
    case emoji_delete(EmojiDelete)
    case webhook_create(Webhook)
    case webhook_delete(WebhookDelete)
    case webhook_update(WebhookUpdate)

    case user_voice_state_update(UserVoiceStateUpdate)
}

struct ReadyEvent: Decodable {
    var users: [User]
    var servers: [Types.Server]
    var channels: [Channel]
    var members: [Member]
    var emojis: [Emoji]
    var voice_states: [ChannelVoiceState]
}

struct UserVoiceState: Decodable, Identifiable {
    var id: String
    var is_receiving: Bool
    var is_publishing: Bool
    var screensharing: Bool
    var camera: Bool
}

struct ChannelVoiceState: Decodable, Identifiable {
    var id: String
    var participants: [UserVoiceState]
}

struct MessageUpdateEventData: Decodable {
    var content: String?
    var edited: String?
    var pinned: Bool?
}

struct MessageUpdateEvent: Decodable {
    enum Remove: String, Decodable {
        case pinned = "Pinned"
    }
    
    var channel: String
    var id: String
    var data: MessageUpdateEventData
    var remove: [Remove]?
}

struct ChannelTyping: Decodable {
    var id: String
    var user: String
}

struct MessageDeleteEvent: Decodable {
    var channel: String
    var id: String
}

struct ChannelAckEvent: Decodable {
    var id: String
    var user: String
    var message_id: String
}

struct VoiceChannelJoin: Decodable {
    var id: String
    var state: UserVoiceState
}

struct VoiceChannelLeave: Decodable {
    var id: String
    var user: String
}

struct MessageReactEvent: Decodable {
    var id: String
    var channel_id: String
    var user_id: String
    var emoji_id: String
}

struct MessageAppend: Decodable {
    var id: String
    var channel: String
    var append: Embed
}

struct BulkEvent: Decodable {
    var v: [WsMessage]
}

struct ErrorEvent: Decodable {
    var data: AnyDecodable
}

struct PongEvent: Decodable {
    var data: AnyDecodable
}

struct MessageRemoveReaction: Decodable {
    var id: String
    var channel_id: String
    var emoji_id: String
}

struct BulkMessageDelete: Decodable {
    var channel: String
    var ids: [String]
}

struct ChannelUpdateEventData: Decodable {
    var name: String?
    var owner: String?
    var description: String?
    var icon: File?
    var nsfw: Bool?
    var active: Bool?
    var permissions: Permissions?
    var role_permissions: [String: Overwrite]?
    var default_permissions: Overwrite?
    var last_message_id: String?
}

struct ChannelUpdate: Decodable {
    enum Remove: String, Decodable {
        case description = "Description"
        case icon = "Icon"
        case default_permissions = "DefaultPermissions"
    }
    
    var id: String
    var data: ChannelUpdateEventData
    var clear: [Remove]?
}

struct ChannelDelete: Decodable {
    var id: String
}

struct ChannelGroupJoin: Decodable {
    var id: String
    var user: String
}

struct ChannelGroupLeave: Decodable {
    var id: String
    var user: String
}

struct ServerCreate: Decodable {
    var id: String
    var server: Types.Server
    var channels: [Channel]
    var emojis: [Emoji]
}

struct ServerUpdateEventData: Decodable {
    var owner: String?
    var name: String?
    var description: String?
    var channels: [String]?
    var categories: [Types.Category]?
    var system_messages: SystemMessages?
    var roles: [String: Role]?
    var default_permissions: Permissions?
    var icon: File?
    var banner: File?
    var flags: ServerFlags?
    var nsfw: Bool?
    var analytics: Bool?
    var discoverable: Bool?
}

struct ServerUpdate: Decodable {
    enum Clear: String, Decodable {
        case description = "Description"
        case categories = "Categories"
        case system_messages = "SystemMessages"
        case icon = "Icon"
        case banner = "Banner"
    }
    
    var id: String
    var data: ServerUpdateEventData
    var clear: [Clear]?
}

struct ServerDelete: Decodable {
    var id: String
}

struct ServerMemberJoin: Decodable {
    var id: String
    var user: String
}

struct ServerMemberUpdateEventData: Decodable {
    var joined_at: String?
    var nickname: String?
    var avatar: File?
    var roles: [String]?
    var timeout: String?
}

struct ServerMemberUpdate: Decodable {
    enum Clear: String, Decodable {
        case nickname = "Nickname"
        case avatar = "AppAvatar"
        case roles = "Roles"
        case timeout = "Timeout"
    }
    
    var id: MemberId
    var data: ServerMemberUpdateEventData
    var clear: [Clear]?
}

struct ServerMemberLeave: Decodable {
    enum Reason: String, Decodable {
        case leave = "Leave"
        case kick = "Kick"
        case ban = "Ban"
    }
    
    var id: String
    var user: String
    var reason: Reason
}

struct ServerRoleUpdateEventData: Decodable {
    var name: String?
    var permissions: Overwrite?
    var colour: String?
    var hoist: Bool?
    var rank: Int?
}

struct ServerRoleUpdate: Decodable {
    enum Clear: String, Decodable {
        case colour = "Colour"
    }
    
    var id: String
    var role_id: String
    var data: ServerRoleUpdateEventData
    var clear: [Clear]?
}

struct ServerRoleDelete: Decodable {
    var id: String
    var role_id: String
}

struct UserUpdateEventData: Decodable {
    var username: String?
    var discriminator: String?
    var display_name: String?
    var avatar: File?
    var relations: [UserRelation]?
    var badges: Int?
    var status: Status?
    var flags: Int?
    var privileged: Bool?
    var bot: UserBot?
    var relationship: Relation?
    var online: Bool?
}

struct UserUpdate: Decodable {
    enum Clear: String, Decodable {
        case avatar = "AppAvatar"
        case status_text = "StatusText"
        case status_presence = "StatusPresence"
        case profile_content = "ProfileContent"
        case profile_background = "ProfileBackground"
        case display_name = "DisplayName"
    }
    
    var id: String
    var data: UserUpdateEventData
    var clear: [Clear]?
}

struct UserRelationship: Decodable {
    var id: String
    var user: User
}

struct UserSettingsUpdate: Decodable {
    var id: String
    var update: [String: Tuple2<Int, String>]
}

struct UserPlatformWipe: Decodable {
    var user_id: String
    var flags: Int
}

struct EmojiDelete: Decodable {
    var id: String
}

struct WebhookUpdateEventData: Decodable {
    var name: String?
    var avatar: File?
    var permissions: Int?
}

struct WebhookUpdate: Decodable {
    enum Remove: String, Decodable {
        case avatar = "AppAvatar"
    }
    
    var id: String
    var data: WebhookUpdateEventData
    var remove: [Remove]?
}

struct WebhookDelete: Decodable {
    var id: String
}

struct UserVoiceStateUpdate: Decodable {
    var id: String
    var channel_id: String
    var data: PartialUserVoiceUpdate
}

extension WsMessage: Decodable {
    enum CodingKeys: String, CodingKey { case type }
    enum Tag: String, Decodable {
        case Authenticated,
             InvalidSession,
             Ready,
             Bulk,
             Error,
             Logout,
             Pong,
             Message,
             MessageUpdate,
             MessageDelete,
             MessageReact,
             MessageUnreact,
             MessageAppend,
             MessageRemoveReaction,
             BulkMessageDelete,
             ChannelStartTyping,
             ChannelStopTyping,
             ChannelCreate,
             ChannelUpdate,
             ChannelDelete,
             ChannelGroupJoin,
             ChannelGroupLeave,
             ChannelAck,
             ServerCreate,
             ServerUpdate,
             ServerDelete,
             ServerMemberJoin,
             ServerMemberUpdate,
             ServerMemberLeave,
             ServerRoleUpdate,
             ServerRoleDelete,
             UserUpdate,
             UserRelationship,
             UserSettingsUpdate,
             UserPlatformWipe,
             EmojiCreate,
             EmojiDelete,
             WebhookCreate,
             WebhookDelete,
             WebhookUpdate,
             VoiceChannelJoin,
             VoiceChannelLeave,
             UserVoiceStateUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let singleValueContainer = try decoder.singleValueContainer()

        switch try container.decode(Tag.self, forKey: .type) {
            case .Authenticated:
                self = .authenticated
            case .InvalidSession:
                self = .invalid_session
            case .Ready:
                self = .ready(try singleValueContainer.decode(ReadyEvent.self))
            case .Message:
                self = .message(try singleValueContainer.decode(Message.self))
            case .MessageUpdate:
                self = .message_update(try singleValueContainer.decode(MessageUpdateEvent.self))
            case .ChannelStartTyping:
                self = .channel_start_typing(try singleValueContainer.decode(ChannelTyping.self))
            case .ChannelStopTyping:
                self = .channel_stop_typing(try singleValueContainer.decode(ChannelTyping.self))
            case .MessageDelete:
                self = .message_delete(try singleValueContainer.decode(MessageDeleteEvent.self))
            case .ChannelAck:
                self = .channel_ack(try singleValueContainer.decode(ChannelAckEvent.self))
            case .VoiceChannelJoin:
                self = .voice_channel_join(try singleValueContainer.decode(VoiceChannelJoin.self))
            case .VoiceChannelLeave:
                self = .voice_channel_leave(try singleValueContainer.decode(VoiceChannelLeave.self))
            case .MessageReact:
                self = .message_react(try singleValueContainer.decode(MessageReactEvent.self))
            case .MessageUnreact:
                self = .message_unreact(try singleValueContainer.decode(MessageReactEvent.self))
            case .MessageAppend:
                self = .message_append(try singleValueContainer.decode(MessageAppend.self))
            case .Bulk:
                self = .bulk(try singleValueContainer.decode(BulkEvent.self))
            case .Error:
                self = .error(try singleValueContainer.decode(ErrorEvent.self))
            case .Logout:
                self = .logout
            case .Pong:
                self = .pong(try singleValueContainer.decode(PongEvent.self))
            case .MessageRemoveReaction:
                self = .message_remove_reaction(try singleValueContainer.decode(MessageRemoveReaction.self))
            case .BulkMessageDelete:
                self = .bulk_message_delete(try singleValueContainer.decode(BulkMessageDelete.self))
            case .ChannelCreate:
                self = .channel_create(try singleValueContainer.decode(Channel.self))
            case .ChannelUpdate:
                self = .channel_update(try singleValueContainer.decode(ChannelUpdate.self))
            case .ChannelDelete:
                self = .channel_delete(try singleValueContainer.decode(ChannelDelete.self))
            case .ChannelGroupJoin:
                self = .channel_group_join(try singleValueContainer.decode(ChannelGroupJoin.self))
            case .ChannelGroupLeave:
                self = .channel_group_leave(try singleValueContainer.decode(ChannelGroupLeave.self))
            case .ServerCreate:
                self = .server_create(try singleValueContainer.decode(ServerCreate.self))
            case .ServerUpdate:
                self = .server_update(try singleValueContainer.decode(ServerUpdate.self))
            case .ServerDelete:
                self = .server_delete(try singleValueContainer.decode(ServerDelete.self))
            case .ServerMemberJoin:
                self = .server_member_join(try singleValueContainer.decode(ServerMemberJoin.self))
            case .ServerMemberUpdate:
                self = .server_member_update(try singleValueContainer.decode(ServerMemberUpdate.self))
            case .ServerMemberLeave:
                self = .server_member_leave(try singleValueContainer.decode(ServerMemberLeave.self))
            case .ServerRoleUpdate:
                self = .server_role_update(try singleValueContainer.decode(ServerRoleUpdate.self))
            case .ServerRoleDelete:
                self = .server_role_delete(try singleValueContainer.decode(ServerRoleDelete.self))
            case .UserUpdate:
                self = .user_update(try singleValueContainer.decode(UserUpdate.self))
            case .UserRelationship:
                self = .user_relationship(try singleValueContainer.decode(UserRelationship.self))
            case .UserSettingsUpdate:
                self = .user_settings_update(try singleValueContainer.decode(UserSettingsUpdate.self))
            case .UserPlatformWipe:
                self = .user_platform_wipe(try singleValueContainer.decode(UserPlatformWipe.self))
            case .EmojiCreate:
                self = .emoji_create(try singleValueContainer.decode(Emoji.self))
            case .EmojiDelete:
                self = .emoji_delete(try singleValueContainer.decode(EmojiDelete.self))
            case .WebhookCreate:
                self = .webhook_create(try singleValueContainer.decode(Webhook.self))
            case .WebhookDelete:
                self = .webhook_delete(try singleValueContainer.decode(WebhookDelete.self))
            case .WebhookUpdate:
                self = .webhook_update(try singleValueContainer.decode(WebhookUpdate.self))
            case .UserVoiceStateUpdate:
                self = .user_voice_state_update(try singleValueContainer.decode(UserVoiceStateUpdate.self))
        }
    }
}

enum WsState {
    case disconnected
    case connecting
    case connected
}

class SendWsMessage: Encodable {
    var type: String

    init(type: String) {
        self.type = type
    }
}

class Authenticate: SendWsMessage, CustomStringConvertible {
    private enum CodingKeys: String, CodingKey { case type, token }

    var token: String

    init(token: String) {
        self.token = token
        super.init(type: "Authenticate")
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(type, forKey: .type)
    }

    var description: String {
        return "Authenticate(token: \(token))"
    }
}

class WebSocketStream: ObservableObject {
    private var url: URL
    private var client: WebSocket
    private var encoder: JSONEncoder
    private var decoder: JSONDecoder
    private var onEvent: (WsMessage) async -> ()
    
    /// Timer that sends periodic pings to keep the connection alive
    private var pingTimer: Timer?
    /// Guard against duplicate reconnection attempts
    private var isReconnecting: Bool = false
    /// Timestamp of last received message for staleness detection
    private var lastMessageTime: Date = Date()

    public var token: String
    @Published public var currentState: WsState = .disconnected
    public var retryCount: Int = 0
    
    /// Debounce timer so very short blips (< 2s) don't flash the banner
    private var disconnectDebounceTask: Task<Void, Never>? = nil
    
    /// Maximum backoff delay in seconds (30s cap)
    private let maxBackoffDelay: Double = 30.0

    init(url: String, token: String, onEvent: @escaping (WsMessage) async -> ()) {
        self.token = token
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.onEvent = onEvent
        self.url = URL(string: url)!
        
        var request = URLRequest(url: self.url)
        request.timeoutInterval = 30
        let ws = WebSocket(request: request)
        client = ws

        ws.onEvent = didReceive
        ws.connect()
    }
    
    deinit {
        stopPingTimer()
    }

    public func stop() {
        stopPingTimer()
        disconnectDebounceTask?.cancel()
        disconnectDebounceTask = nil
        isReconnecting = false
        client.disconnect(closeCode: .zero)
    }
    
    /// Start a periodic ping every 15 seconds to keep the WebSocket alive
    private func startPingTimer() {
        stopPingTimer()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self, self.currentState == .connected else { return }
                self.client.write(ping: Data())
                
                // Check for stale connection (no message in 60s)
                if Date().timeIntervalSince(self.lastMessageTime) > 60 {
                    print("WebSocket: Connection appears stale, forcing reconnect")
                    self.currentState = .disconnected
                    self.client.disconnect(closeCode: .zero)
                    Task { [weak self] in
                        await self?.tryReconnect()
                    }
                }
            }
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    public func didReceive(event: WebSocketEvent) {
        switch event {
            case .connected(_):
                // TCP connected — send auth. Don't update WsState yet;
                // wait for Authenticated message before claiming "connected".
                // This avoids the "Connecting..." flash on every reconnect.
                isReconnecting = false
                disconnectDebounceTask?.cancel()
                disconnectDebounceTask = nil
                let payload = Authenticate(token: token)
                print(payload.description)
                let s = try! encoder.encode(payload)
                client.write(string: String(data: s, encoding: .utf8)!)
                    
            case .disconnected(let reason, _):
                print("disconnect \(reason)")
                stopPingTimer()
                // Debounce: only report disconnect after 2s so transient blips are silent
                disconnectDebounceTask?.cancel()
                disconnectDebounceTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self, !Task.isCancelled else { return }
                    self.currentState = .disconnected
                    await self.tryReconnect()
                }

            case .text(let string):
                lastMessageTime = Date()

                do {
                    let e = try decoder.decode(WsMessage.self, from: string.data(using: .utf8)!)
                    
                    // On successful authentication, mark as fully connected
                    if case .authenticated = e {
                        retryCount = 0
                        isReconnecting = false
                        currentState = .connected
                        startPingTimer()
                    }

                    Task {
                        await onEvent(e)
                    }
                } catch {
                    print(error)
                }
                
            case .viabilityChanged(let viability):
                if !viability {
                    stopPingTimer()
                    // Debounce viability changes — they often flap briefly on Wi-Fi handoffs
                    disconnectDebounceTask?.cancel()
                    disconnectDebounceTask = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        guard let self, !Task.isCancelled else { return }
                        self.currentState = .disconnected
                        await self.tryReconnect()
                    }
                } else {
                    disconnectDebounceTask?.cancel()
                    disconnectDebounceTask = nil
                }

            case .error(let error):
                stopPingTimer()
                self.stop()
                print("error \(String(describing: error))")
                disconnectDebounceTask?.cancel()
                disconnectDebounceTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    self.currentState = .disconnected
                    await self.tryReconnect()
                }
            
            case .pong(_):
                lastMessageTime = Date()
                
            default:
                break
        }
    }
    
    func forceConnect() {
        stopPingTimer()
        isReconnecting = false
        
        var request = URLRequest(url: self.url)
        request.timeoutInterval = 30
        let ws = WebSocket(request: request)
        
        client = ws
        
        ws.onEvent = didReceive
        ws.connect()
    }
    
    func tryReconnect() async {
        // Prevent duplicate reconnection attempts
        guard !isReconnecting else { return }
        isReconnecting = true
        
        // Exponential backoff with cap and jitter
        let baseDelay = min(0.5 * pow(2.0, Double(retryCount)), maxBackoffDelay)
        let jitter = Double.random(in: 0...(baseDelay * 0.3))
        let delay = baseDelay + jitter
        
        print("WebSocket: Reconnecting in \(String(format: "%.1f", delay))s (attempt \(retryCount + 1))")
        
        try? await Task.sleep(for: .seconds(delay))
        
        // Only proceed if we're still disconnected
        guard currentState == .disconnected else {
            isReconnecting = false
            return
        }
        
        // Set connecting state only right before actually trying
        currentState = .connecting
        forceConnect()
        retryCount += 1
    }
}

