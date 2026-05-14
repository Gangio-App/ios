//
//  Utils.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import ULID
import Types

func createdAt(id: String) -> Date {
    // Safely decode ULID timestamp; fall back to a sentinel "now" date for non-ULID
    // ids so callers don't crash. We previously force-unwrapped which produced
    // nonsensical or "Member Since 2019" looking dates for legacy ids.
    if id.count == 26, let ulid = ULID(ulidString: id) {
        return ulid.timestamp
    }
    return Date()
}

enum FileCategory: String {
    case attachment = "attachments"
    case avatar = "avatars"
    case background = "backgrounds"
    case icon = "icons"
    case banner = "banners"
    case emoji = "emojis"
}

enum ChannelType {
    case text, voice, group, dm, saved
}

protocol Messageable: Identifiable {
    var channelType: ChannelType { get }
}

struct LocalFile: Equatable {
    var content: Data
    var filename: String
}

enum SettingImage: Equatable {
    case remote(File?)
    case local(LocalFile?)
}

enum Icon: Equatable {
    case remote(File?)
    case local(Data)
}

func formatMessageDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.timeStyle = .short
    
    if calendar.isDateInToday(date) {
        return "Today at \(timeFormatter.string(from: date))"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday at \(timeFormatter.string(from: date))"
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }
}
