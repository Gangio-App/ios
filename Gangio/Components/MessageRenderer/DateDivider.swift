//
//  DateDivider.swift
//  Gangio
//
//  Discord-like date divider that separates messages by day in the channel timeline.
//

import SwiftUI

struct DateDivider: View {
    @EnvironmentObject var viewState: AppViewState
    let date: Date
    
    private var displayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            formatter.doesRelativeDateFormatting = false
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(viewState.theme.foreground3.color.opacity(0.25))
                .frame(height: 1)
            
            Text(displayText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(viewState.theme.foreground2.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewState.theme.background2.color)
                )
                .overlay(
                    Capsule()
                        .stroke(viewState.theme.foreground3.color.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 8)
            
            Rectangle()
                .fill(viewState.theme.foreground3.color.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        DateDivider(date: Date())
        DateDivider(date: Date().addingTimeInterval(-86400))
        DateDivider(date: Date().addingTimeInterval(-86400 * 7))
    }
    .padding()
    .applyPreviewModifiers(withState: AppViewState.preview())
}
