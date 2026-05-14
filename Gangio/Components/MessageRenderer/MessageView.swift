//
//  Message.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types
import Gangio

struct MessageView: View {
    private enum AvatarSize {
        case regular
        case compact
        
        var sizes: (CGFloat, CGFloat, CGFloat) {
            switch self {
                case .regular:
                    return (40, 20, 5)   // Discord: 40pt avatar
                case .compact:
                    return (18, 9, 2)
            }
        }
    }
    @ObservedObject var viewModel: MessageContentsViewModel
    
    @EnvironmentObject var viewState: AppViewState
    
    @State var showReportSheet: Bool = false
    @State var isStatic: Bool = false
    @State var onlyShowContent: Bool = false
    
    var isCompactMode: (Bool, Bool) {
        return TEMP_IS_COMPACT_MODE
    }
    
    // Resolve the live message + author + member directly from viewState so any
    // change to viewState.messages/users/members triggers a re-render here.
    private var resolvedMessage: Message {
        viewState.messages[viewModel.messageId]
            ?? Message(id: viewModel.messageId, content: nil, author: "", channel: viewModel.channelId)
    }
    private var resolvedAuthor: User {
        viewState.users[resolvedMessage.author]
            ?? User(id: String(repeating: "0", count: 26), username: "Unknown", discriminator: "0000")
    }
    private var resolvedMember: Member? {
        guard let sid = viewModel.server?.id else { return nil }
        return viewState.members[sid]?[resolvedMessage.author]
    }
    
    private func pfpView(size: AvatarSize, message: Message, author: User, member: Member?) -> some View {
        Button {
            if !isStatic || message.webhook != nil {
                viewState.openUserSheet(withId: author.id, server: viewModel.server?.id)
            }
        } label: {
            ZStack(alignment: .topLeading) {
                AppAvatar(user: author, member: member, masquerade: message.masquerade, webhook: message.webhook, width: size.sizes.0, height: size.sizes.0)
                
                if message.masquerade != nil {
                    AppAvatar(user: author, member: member, webhook: message.webhook, width: size.sizes.1, height: size.sizes.1)
                        .padding(.leading, -size.sizes.2)
                        .padding(.top, -size.sizes.2)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func nameView(message: Message, author: User, member: Member?) -> some View {
        let name = message.webhook?.name
            ?? message.masquerade?.name
            ?? member?.nickname
            ?? author.display_name
            ?? author.username
        
        return Text(verbatim: name)
            .onTapGesture {
                if !isStatic || message.webhook != nil {
                    viewState.openUserSheet(withId: author.id, server: viewModel.server?.id)
                }
            }
            .foregroundStyle({
                if let member = member, let server = viewModel.server {
                    return member.displayColour(theme: viewState.theme, server: server) ?? AnyShapeStyle(viewState.theme.foreground.color)
                }
                return AnyShapeStyle(viewState.theme.foreground.color)
            }())
            .font(.body)
            .fontWeight(.bold)
    }
    
    var body: some View {
        // Read once per render — establishes a SwiftUI dependency on
        // viewState.messages/users/members for this body so updates re-render.
        let message = resolvedMessage
        let author = resolvedAuthor
        let member = resolvedMember
        
        VStack(alignment: .leading, spacing: 4) {
            if let replies = message.replies {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(replies, id: \.self) { id in
                        MessageReplyView(
                            mentions: .constant(message.mentions),
                            channelScrollPosition: viewModel.channelScrollPosition,
                            id: id,
                            server: viewModel.server,
                            channel: viewModel.channel
                        )
                            .padding(.leading, 48)
                    }
                }
            }
            
            if message.system != nil {
                SystemMessageView(message: .constant(message))
            } else {
                if isCompactMode.0 {
                    HStack(alignment: .top, spacing: 4) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(formatMessageDate(createdAt(id: message.id)))
                                .font(.caption)
                                .foregroundStyle(viewState.theme.foreground2)
                            
                            if isCompactMode.1 {
                                pfpView(size: .compact, message: message, author: author, member: member)
                            }
                            
                            nameView(message: message, author: author, member: member)
                            
                            if author.bot != nil {
                                MessageBadge(text: String(localized: "Bot"), color: viewState.theme.accent.color)
                            }
                        }
                        
                        MessageContentsView(viewModel: viewModel, onlyShowContent: onlyShowContent)
                        
                        if message.edited != nil {
                            Text("(edited)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        // AppAvatar (Discord: 40pt)
                        pfpView(size: .regular, message: message, author: author, member: member)
                            .padding(.top, 1)
                            .padding(.trailing, 12)

                        VStack(alignment: .leading, spacing: 2) {
                            // Name + timestamp row
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                nameView(message: message, author: author, member: member)
                                    .font(.system(size: 15, weight: .semibold))

                                if author.bot != nil {
                                    MessageBadge(text: String(localized: "Bot"), color: viewState.theme.accent.color)
                                }
                                if message.webhook != nil {
                                    MessageBadge(text: String(localized: "Webhook"), color: viewState.theme.accent.color)
                                }

                                Text(formatMessageDate(createdAt(id: message.id)))
                                .font(.system(size: 11))
                                .foregroundStyle(viewState.theme.foreground2.color.opacity(0.6))

                                if message.edited != nil {
                                    Text("(edited)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                            }

                            MessageContentsView(viewModel: viewModel, onlyShowContent: onlyShowContent)
                        }
                    }
                }
            }
        }
        .font(Font.system(size: 14.0))
        .listRowSeparator(.hidden)
        .environment(\.currentMessage, viewModel)
    }
}

//struct GhostMessageView: View {
//    @EnvironmentObject var viewState: AppViewState
//    
//    var message: QueuedMessage
//    
//    var body: some View {
//        HStack(alignment: .top) {
//            AppAvatar(user: viewState.currentUser!, width: 16, height: 16)
//            VStack(alignment: .leading) {
//                HStack {
//                    Text(viewState.currentUser!.username)
//                        .fontWeight(.heavy)
//                    Text(createdAt(id: message.nonce).formatted())
//                }
//                Contents(text: message.content)
//                //.frame(maxWidth: .infinity, alignment: .leading)
//            }
//            //.frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .listRowSeparator(.hidden)
//    }
//}

struct MessageView_Previews: PreviewProvider {
    static var viewState: AppViewState = AppViewState.preview()
    @State static var message = viewState.messages["01HDEX6M2E3SHY8AC2S6B9SEAW"]!
    @State static var channel = viewState.channels["0"]!
    @State static var server = viewState.servers["0"]
    @State static var replies: [Reply] = []
    @State static var highlighted: String? = nil
    
    static var previews: some View {
        ScrollViewReader { p in
            List {
                MessageView(
                    viewModel: MessageContentsViewModel(
                        viewState: viewState,
                        messageId: message.id,
                        channelId: channel.id,
                        server: $server,
                        channel: $channel,
                        replies: $replies,
                        channelScrollPosition: ChannelScrollController(proxy: p, highlighted: $highlighted),
                        editing: .constant(nil)
                    ),
                    isStatic: false
                )
            }
        }
        .applyPreviewModifiers(withState: viewState)
    }
}
