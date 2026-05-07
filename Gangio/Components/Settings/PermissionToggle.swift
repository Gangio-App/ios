//
//  PermissionToggle.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI


struct PermissionToggle<Label: View>: View {
    @Binding var value: Bool?
    @ViewBuilder var label: () -> Label
    
    var body: some View {
        HStack {
            label()
            
            Spacer()
            
            Picker("Select permission", selection: $value) {
                Image(systemName: "xmark")
                    .foregroundStyle(.red, .red)
                    .tag(Optional.some(false))
                
                Image(systemName: "square")
                    .tag(nil as Bool?)
                
                Image(systemName: "checkmark")
                    .foregroundStyle(.green, .green)
                    .tag(Optional.some(true))
            }
            .tint(value == true ? .green : value == false ? .red : nil)
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }
}
