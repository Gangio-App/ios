//
//  Role.swift
//  Types
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation

public struct Role: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var permissions: Overwrite
    public var colour: String?
    public var hoist: Bool?
    public var rank: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, permissions, colour, hoist, rank
    }
}
