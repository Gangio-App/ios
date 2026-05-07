//
//  Collection.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
