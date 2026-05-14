//
//  MessageContentsView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

@MainActor
class MessageContentsViewModel: ObservableObject, Equatable, Identifiable {
    var viewState: AppViewState
    
    // Stable identifiers — never change for the lifetime of this VM.
    let messageId: String
    let channelId: String
    
    // Channel-level state still uses bindings because it's owned upstream.
    @Binding var server: Server?
    @Binding var channel: Channel
    @Binding var channelReplies: [Reply]
    @Binding var editing: Message?
    
    var channelScrollPosition: ChannelScrollController
    
    init(
        viewState: AppViewState,
        messageId: String,
        channelId: String,
        server: Binding<Server?>,
        channel: Binding<Channel>,
        replies: Binding<[Reply]>,
        channelScrollPosition: ChannelScrollController,
        editing: Binding<Message?>
    ) {
        self.viewState = viewState
        self.messageId = messageId
        self.channelId = channelId
        self._server = server
        self._channel = channel
        self._channelReplies = replies
        self.channelScrollPosition = channelScrollPosition
        self._editing = editing
    }
    
    static func == (lhs: MessageContentsViewModel, rhs: MessageContentsViewModel) -> Bool {
        lhs.messageId == rhs.messageId
    }
    
    var id: String { messageId }
    
    /// IMPORTANT: This is a computed convenience accessor. Reading it from a
    /// SwiftUI view body will NOT establish a re-render dependency on
    /// `viewState.messages[messageId]` — only direct reads against the
    /// view's own `@EnvironmentObject` do that. Use this in non-body
    /// contexts (button actions, async tasks). View bodies should resolve
    /// the message via `viewState.messages[viewModel.messageId]` directly.
    var message: Message {
        viewState.messages[messageId] ?? Message(id: messageId, content: nil, author: "", channel: channelId)
    }
    
    var author: User {
        viewState.users[message.author] ?? User(id: String(repeating: "0", count: 26), username: "Unknown", discriminator: "0000")
    }
    
    var member: Member? {
        guard let sid = server?.id else { return nil }
        return viewState.members[sid]?[message.author]
    }
    
    func delete() async {
        // Capture identifiers up-front so we never touch potentially-invalidated
        // bindings later in the function.
        let channelId = self.channelId
        let messageId = self.messageId
        
        // Step 1: Clear all state that *references* the message id BEFORE
        // removing the message itself.
        await MainActor.run {
            channelReplies.removeAll { $0.message.id == messageId }
            if editing?.id == messageId {
                editing = nil
            }
        }
        
        // Step 2: Snapshot, then optimistically remove from both
        // `messages` and `channelMessages` in one MainActor hop.
        let removedMessage = await MainActor.run { () -> Message? in
            let removed = viewState.messages.removeValue(forKey: messageId)
            if var channelMsgs = viewState.channelMessages[channelId] {
                channelMsgs.removeAll { $0 == messageId }
                viewState.channelMessages[channelId] = channelMsgs
            }
            return removed
        }
        
        // Step 3: Send delete request.
        let result = await viewState.http.deleteMessage(channel: channelId, message: messageId)
        
        // Step 4: Restore on failure.
        if case .failure = result, let restored = removedMessage {
            await MainActor.run {
                viewState.messages[messageId] = restored
                if var channelMsgs = viewState.channelMessages[channelId] {
                    if !channelMsgs.contains(messageId) {
                        channelMsgs.append(messageId)
                        channelMsgs.sort()
                    }
                    viewState.channelMessages[channelId] = channelMsgs
                }
            }
        }
    }
    
    func reply() {
        let snapshot = message
        if !channelReplies.contains(where: { $0.message.id == messageId }) && channelReplies.count < 5 {
            withAnimation {
                channelReplies.append(Reply(message: snapshot))
            }
        }
    }
    
    func pin() async {
        await viewState.http.pinMessage(channel: channelId, message: messageId)
    }
    
    func unpin() async {
        await viewState.http.unpinMessage(channel: channelId, message: messageId)
    }
}

struct MessageContentsView: View {
    @EnvironmentObject var viewState: AppViewState
    @ObservedObject var viewModel: MessageContentsViewModel

    @Environment(\.channelMessageSelection) @Binding var channelMessageSelection
        
    var onlyShowContent: Bool = false

    var body: some View {
        // Resolve the message directly from viewState so SwiftUI tracks
        // viewState.messages as a body-level dependency. This is what makes
        // edits/reactions/embed updates re-render automatically.
        let message = viewState.messages[viewModel.messageId]
            ?? Message(id: viewModel.messageId, content: nil, author: "", channel: viewModel.channelId)
        
        VStack(alignment: .leading, spacing: 4) {
            if let content = message.content, !content.isEmpty {
                Contents(text: .constant(content), fontSize: CGFloat(viewState.messageFontSize))
            }
            
            // Server invite embeds detected from message content
            if !onlyShowContent, let content = message.content, !content.isEmpty {
                let inviteCodes = InviteCodeDetector.extractCodes(from: content)
                if !inviteCodes.isEmpty {
                    ForEach(inviteCodes.prefix(3), id: \.self) { code in
                        InviteEmbed(code: code)
                    }
                }
            }
            
            if !onlyShowContent, let embeds = message.embeds, !embeds.isEmpty {
                ForEach(Array(embeds.enumerated()), id: \.offset) { _, embed in
                    MessageEmbed(embed: .constant(embed))
                }
            }
            
            if !onlyShowContent, let attachments = message.attachments {
                VStack(alignment: .leading) {
                    ForEach(attachments) { attachment in
                        MessageAttachment(attachment: attachment)
                    }
                }
            }
            
            MessageReactions(
                channel: viewModel.channel,
                message: message,
                reactions: .constant(message.reactions),
                interactions: .constant(message.interactions)
            )
        }
        .environment(\.currentMessage, viewModel)
    }
}

