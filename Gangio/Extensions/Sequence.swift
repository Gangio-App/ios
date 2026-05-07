//
//  Sequence.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        
        for element in self {
            try await values.append(transform(element))
        }
        
        return values
    }
}
