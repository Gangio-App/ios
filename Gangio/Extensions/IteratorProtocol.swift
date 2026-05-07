//
//  IteratorProtocol.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

extension IteratorProtocol {
    mutating func next(n: Int) -> [Self.Element] {
        var values: [Self.Element] = []
        
        for _ in 0...n {
            if let v = self.next() {
                values.append(v)
            }
        }
        
        return values
    }
    
    mutating func groups(n: Int) -> [[Self.Element]] {
        var values: [[Self.Element]] = []
        
        while true {
            let group = self.next(n: n)
            
            if group.count > 0 {
                values.append(group)
            }
            
            if group.count != n {
                return values
            }
        }
    }
}
