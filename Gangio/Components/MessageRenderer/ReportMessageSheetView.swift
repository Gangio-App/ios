//
//  ReportMessageSheetView.swift
//  Gangio
//
//  Created by Angelo Manca on 2023-11-05.
//
//  Now wraps the unified ReportSheet component.
//

import SwiftUI
import Types

/// Thin wrapper kept for call-site compatibility.
struct ReportMessageSheetView: View {
    @Binding var showSheet: Bool
    @ObservedObject var messageView: MessageContentsViewModel

    var body: some View {
        ReportSheet(target: .message(messageView.message))
    }
}

