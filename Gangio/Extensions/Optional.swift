//
//  Optional.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

extension Optional {
    enum Error: Swift.Error {
        case unexpectedNil
    }
    
    func unwrapped() throws -> Wrapped {
        if let self { return self }
        else { throw Error.unexpectedNil }
    }
}
