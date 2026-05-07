//
//  Webhook.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

public struct Webhook: Codable, Hashable, Equatable, Identifiable {
    public init(id: String, name: String, avatar: File? = nil, creator_id: String, channel_id: String, permissions: Int, token: String? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.creator_id = creator_id
        self.channel_id = channel_id
        self.permissions = permissions
        self.token = token
    }
    
    public var id: String
    public var name: String
    public var avatar: File?
    public var creator_id: String
    public var channel_id: String
    public var permissions: Int
    public var token: String?
}
