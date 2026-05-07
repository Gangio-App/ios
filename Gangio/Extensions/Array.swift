//
//  Array.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation


extension Array where Element: Identifiable {
    var ids: [Element.ID] {
        map(\.id)
    }
}
