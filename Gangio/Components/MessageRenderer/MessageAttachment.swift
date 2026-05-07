//
//  MessageAttachment.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import AVKit
import Types

var fmt = ByteCountFormatter()

struct MessageAttachment: View {
    @EnvironmentObject var viewState: AppViewState
    var attachment: File
    
        
    var body: some View {
        switch attachment.metadata {
            case .image(_):
                LazyImage(source: .file(attachment), clipTo: RoundedRectangle(cornerRadius: 12))
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewState.fullScreenImage = attachment
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .padding(6)
                            .background(.black.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .padding(8)
                    }

            case .video(_):
                VideoPlayer(player: AVPlayer(url: URL(string: viewState.formatUrl(with: attachment))!))
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)

            case .file(_), .text(_), .audio(_):
                HStack(alignment: .center) {
                    Image(systemName: "doc")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading) {
                        Text(attachment.filename)
                        Text(fmt.string(fromByteCount: attachment.size))
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    
                    Spacer()
                    
                    Button {
                        print("todo")
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                }
                .background(viewState.theme.background2.color)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            @unknown default:
                EmptyView()
        }
    }
}
