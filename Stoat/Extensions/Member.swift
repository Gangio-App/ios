//
//  Member.swift
//  Revolt
//
//  Created by Angelo on 2024-07-18.
//

import Foundation
import Types
import SwiftUI

extension Member {
    public func displayColour(theme: Theme, server: Server) -> AnyShapeStyle? {
        guard let roles = roles else { return nil }
        
        // Revolt rank system: lower rank number = higher priority (same as permissions calculator)
        let coloredRoles = roles
            .compactMap { server.roles?[$0] }
            .filter { $0.colour != nil }
            .sorted(by: { $0.rank < $1.rank })
            
        if let highestColoredRole = coloredRoles.first, let colour = highestColoredRole.colour {
            return parseCSSColorToShapeStyle(currentTheme: theme, input: colour)
        }
        
        return nil
    }
}
