//
//  ReportSheet.swift
//  Gangio
//
//  A unified report sheet matching the web client's report categories.
//

import SwiftUI
import Types

#if !NOTIFICATION_SERVICE && !TYPES && !APP_EXTENSION

// MARK: - Message report reasons (matching web client)

// MARK: - Message report reasons (matching web client)

enum MessageReportReason: String, CaseIterable {
    case illegal         = "Illegal"
    case illegalGoods    = "IllegalGoods"
    case illegalExtort   = "IllegalExtortion"
    case illegalPorn     = "IllegalPornography"
    case illegalHacking  = "IllegalHacking"
    case extremeViolence = "ExtremeViolence"
    case promotesHarm    = "PromotesHarm"
    case spam            = "UnsolicitedSpam"
    case raid            = "Raid"
    case spamAbuse       = "SpamAbuse"
    case scams           = "ScamsFraud"
    case malware         = "Malware"
    case harassment      = "Harassment"
    case noneSpecified   = "NoneSpecified"

    var displayName: String {
        switch self {
        case .illegal:         return "Content breaks one or more laws"
        case .illegalGoods:    return "Drugs or illegal goods"
        case .illegalExtort:   return "Extortion or blackmail"
        case .illegalPorn:     return "Revenge or underage pornography"
        case .illegalHacking:  return "Illegal hacking or cracking"
        case .extremeViolence: return "Extreme violence, gore, or animal cruelty"
        case .promotesHarm:    return "Promotes harm"
        case .spam:            return "Unsolicited advertising or spam"
        case .raid:            return "Raid or spam attack"
        case .spamAbuse:       return "Spam or platform abuse"
        case .scams:           return "Scams or fraud"
        case .malware:         return "Malware or phishing"
        case .harassment:      return "Harassment or cyberbullying"
        case .noneSpecified:   return "Other"
        }
    }
}

// MARK: - User report reasons (matching web client)

enum UserReportReason: String, CaseIterable {
    case spam           = "UnsolicitedSpam"
    case spamAbuse      = "SpamAbuse"
    case inappropriate  = "InappropriateProfile"
    case impersonation  = "Impersonation"
    case banEvasion     = "BanEvasion"
    case underage       = "Underage"
    case noneSpecified  = "NoneSpecified"

    var displayName: String {
        switch self {
        case .spam:          return "Unsolicited advertising or spam"
        case .spamAbuse:     return "Spam or platform abuse"
        case .inappropriate: return "User's profile has inappropriate content"
        case .impersonation: return "Impersonation"
        case .banEvasion:    return "Ban evasion"
        case .underage:      return "Not of minimum age to use the platform"
        case .noneSpecified: return "Other"
        }
    }
}

// MARK: - User report payload

struct UserReportApiPayload: Encodable {
    struct Content: Encodable {
        var type: String = "User"
        var id: String
        var report_reason: String
    }
    var content: Content
    var additional_context: String

    init(userId: String, reason: String, additionalContext: String) {
        self.content = Content(id: userId, report_reason: reason)
        self.additional_context = additionalContext
    }
}

// MARK: - Unified ReportSheet

struct ReportSheet: View {
    enum Target {
        case message(Message)
        case user(User)
    }

    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let target: Target

    @State private var selectedMessageReason: MessageReportReason? = nil
    @State private var selectedUserReason: UserReportReason? = nil
    @State private var additionalContext: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var submitted = false

    private var isDark: Bool { colorScheme == .dark }
    private var bg: Color { isDark ? Color(white: 0.07) : Color(white: 0.95) }
    private var card: Color { isDark ? Color(white: 0.13) : Color.white }

    private var title: String {
        switch target {
        case .message: return "Report Message"
        case .user:    return "Report User"
        }
    }

    private var canSubmit: Bool {
        switch target {
        case .message:
            guard let r = selectedMessageReason else { return false }
            if r == .noneSpecified {
                return !additionalContext.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return true
        case .user:
            guard let r = selectedUserReason else { return false }
            if r == .noneSpecified {
                return !additionalContext.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if submitted {
                    submittedView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            targetPreview.padding(.top, 8)
                            reasonSection
                            contextSection
                            if let err = errorMessage {
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            submitButton
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Target preview

    @ViewBuilder
    private var targetPreview: some View {
        switch target {
        case .user(let user):
            HStack(spacing: 14) {
                AppAvatar(user: user, width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.display_name ?? user.username)
                        .font(.headline)
                    Text("@\(user.username)#\(user.discriminator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)

        case .message(let message):
            VStack(alignment: .leading, spacing: 8) {
                if let author = viewState.users[message.author] {
                    HStack(spacing: 8) {
                        AppAvatar(user: author, width: 28, height: 28)
                        Text(author.display_name ?? author.username)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                }
                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding(16)
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Reason picker

    @ViewBuilder
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT A REASON")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                switch target {
                case .message:
                    let reasons = MessageReportReason.allCases
                    ForEach(Array(reasons.enumerated()), id: \.offset) { idx, reason in
                        reasonRow(
                            label: reason.displayName,
                            isSelected: selectedMessageReason == reason
                        ) { withAnimation(.easeInOut(duration: 0.15)) { selectedMessageReason = reason } }
                        if idx < reasons.count - 1 { Divider().padding(.leading, 16) }
                    }
                case .user:
                    let reasons = UserReportReason.allCases
                    ForEach(Array(reasons.enumerated()), id: \.offset) { idx, reason in
                        reasonRow(
                            label: reason.displayName,
                            isSelected: selectedUserReason == reason
                        ) { withAnimation(.easeInOut(duration: 0.15)) { selectedUserReason = reason } }
                        if idx < reasons.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
            }
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func reasonRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? viewState.theme.accent.color : .secondary)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(isDark ? .white : .black)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Additional context

    @ViewBuilder
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADDITIONAL CONTEXT (OPTIONAL)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            TextField("Give us some detail about this report...", text: $additionalContext, axis: .vertical)
                .lineLimit(4...8)
                .padding(14)
                .background(card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Submit Report")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? viewState.theme.accent.color : Color.gray.opacity(0.35))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit || isSubmitting)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: canSubmit)
    }

    private var submittedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.green)
            Text("Report Submitted")
                .font(.title2.bold())
            Text("Thank you. Our team will review this report.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewState.theme.accent.color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Submit logic

    @MainActor
    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let context = additionalContext.trimmingCharacters(in: .whitespaces)
        let result: Result<EmptyResponse, GangioError>

        switch target {
        case .message(let msg):
            let reason = selectedMessageReason!
            let payload = ContentReportPayload(
                type: .Message,
                contentId: msg.id,
                reason: ContentReportPayload.ContentReportReason(rawValue: reason.displayName) ?? .NoneSpecified,
                userContext: context
            )
            result = await viewState.http.req(method: .post, route: "/safety/report", parameters: payload)

        case .user(let user):
            let reason = selectedUserReason!
            let payload = UserReportApiPayload(
                userId: user.id,
                reason: reason.rawValue,
                additionalContext: context
            )
            result = await viewState.http.req(method: .post, route: "/safety/report", parameters: payload)
        }

        switch result {
        case .success:
            withAnimation { submitted = true }
        case .failure:
            errorMessage = "Failed to submit. Please try again."
        }
    }
}

#endif
