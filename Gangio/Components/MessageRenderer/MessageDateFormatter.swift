import Foundation

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
