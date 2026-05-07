//
//  Member.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import Types
import SwiftUI

extension Member {
    public func displayColour(theme: Theme, server: Server) -> AnyShapeStyle? {
        guard let roles = roles else { return nil }
        
        // Gangio rank system: lower rank number = higher priority (same as permissions calculator)
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
