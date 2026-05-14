//
//  User.swift
//  Types
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation

public struct UserBot: Codable, Equatable, Hashable {
    public var owner: String
}

public enum Presence: String, Codable, Equatable, Hashable {
    case Busy
    case Idle
    case Invisible
    case Online
    case Focus
    case Unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let status = try? container.decode(String.self)
        self = Presence(rawValue: status ?? "Online") ?? .Unknown
    }
}

public enum Relation: String, Codable, Equatable, Hashable {
    case Blocked
    case BlockedOther
    case Friend
    case Incoming
    case None
    case Outgoing
    case User
    case Unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rel = try? container.decode(String.self)
        self = Relation(rawValue: rel ?? "None") ?? .Unknown
    }
}

public struct Status: Codable, Equatable, Hashable {
    public init(text: String? = nil, presence: Presence? = nil) {
        self.text = text
        self.presence = presence
    }
    
    public var text: String?
    public var presence: Presence?
}

public struct UserRelation: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var status: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status
    }
}

public struct User: Identifiable, Codable, Equatable, Hashable {
    public init(id: String, username: String, discriminator: String, display_name: String? = nil, avatar: File? = nil, relations: [UserRelation]? = nil, badges: Int? = nil, status: Status? = nil, relationship: Relation? = nil, online: Bool? = nil, flags: Int? = nil, bot: UserBot? = nil, privileged: Bool? = nil, profile: Profile? = nil) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.display_name = display_name
        self.avatar = avatar
        self.relations = relations
        self.badges = badges
        self.status = status
        self.relationship = relationship
        self.online = online
        self.flags = flags
        self.bot = bot
        self.privileged = privileged
        self.profile = profile
    }

    public var id: String
    public var username: String
    public var discriminator: String
    public var display_name: String?
    public var avatar: File?
    public var relations: [UserRelation]?
    public var badges: Int?
    public var status: Status?
    public var relationship: Relation?
    public var online: Bool?
    public var flags: Int?
    public var bot: UserBot?
    public var privileged: Bool?
    public var profile: Profile?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username, discriminator, display_name, avatar, relations, badges, status, relationship, online, flags, bot, privileged
    }
    
    /// The presence value to actually display in the UI.
    ///
    /// Mirrors what web/desktop clients show:
    ///   - Bot users are treated as always reachable. Backends almost never
    ///     flip the `online` flag for bots (they don't hold a persistent
    ///     gateway connection the same way humans do), so without this
    ///     bots like RoleBot/ModBot would forever show as Offline on iOS
    ///     even though they're clearly online on every other client.
    ///   - For humans: `online == true` is required. If the gateway hasn't
    ///     reported them as online yet, they're shown as Offline — this is
    ///     why disconnected users no longer leak through with a stale
    ///     cached `status.presence` of Online.
    ///   - `Invisible` is always rendered as Offline, regardless of the
    ///     connection state, again matching other clients.
    ///   - A connected user with no explicit presence falls back to Online,
    ///     which is the default everywhere else.
    public var effectivePresence: Presence? {
        let connected = online == true || bot != nil
        guard connected else { return nil }
        if let p = status?.presence, p == .Invisible { return nil }
        return status?.presence ?? .Online
    }
    
    /// Whether this user should be considered online for UI purposes.
    public var isOnline: Bool {
        return effectivePresence != nil
    }
}

public struct Profile: Codable, Equatable, Hashable {
    public init(content: String? = nil, background: File? = nil) {
        self.content = content
        self.background = background
    }
    
    public var content: String?
    public var background: File?
}
