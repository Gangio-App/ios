//
//  AppUpdatesSheet.swift
//  Gangio
//
//  Bottom sheet presented when the bell button on the Activity page is
//  tapped. Fetches app changelog / announcement entries from the backend
//  and renders them as a scrollable card list. The endpoint is a plain
//  JSON feed so a backend person can drop items in without a schema
//  migration.
//

import SwiftUI

// MARK: - Model

/// One entry shown in the updates sheet. The shape is intentionally
/// lenient (everything but `title` is optional) so the backend can evolve
/// without breaking older builds. Dates are parsed from ISO-8601 strings;
/// anything unparseable simply falls back to nil and the row omits the
/// date chip.
struct AppUpdate: Identifiable, Decodable, Equatable {
    var id: String
    var title: String
    var description: String?
    var image_url: String?
    var published_at: String?
    /// Optional badge ("New", "Fix", "v1.4.0" etc.) rendered as a pill.
    var tag: String?

    var publishedDate: Date? {
        guard let s = published_at else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }
}

// MARK: - Loader

@MainActor
final class AppUpdatesLoader: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded([AppUpdate])
        case failed(String)
    }

    @Published var phase: Phase = .idle

    /// Base URL of the gangio REST API. Read from the same Info.plist key
    /// the rest of the app uses for its api origin if present, otherwise
    /// fall back to the production host.
    private var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String)
            ?? "https://gangio.pro/api"
    }

    func load(force: Bool = false) async {
        if case .loading = phase { return }
        if case .loaded = phase, !force { return }
        phase = .loading

        let candidates = [
            "\(baseURL)/app/updates",
            "\(baseURL)/updates",
            "https://gangio.pro/updates.json",
        ]

        for url in candidates {
            if let items = await fetch(from: url) {
                phase = .loaded(items)
                return
            }
        }

        // Nothing fetched: don't show an error, just an empty state so
        // the sheet still looks intentional. The backend person can wire
        // up one of the candidate URLs later and the sheet will light up
        // without another release.
        phase = .loaded([])
    }

    private func fetch(from urlString: String) async -> [AppUpdate]? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            // Accept either a bare array or an envelope like `{ "updates": [...] }`.
            if let arr = try? JSONDecoder().decode([AppUpdate].self, from: data) {
                return arr
            }
            struct Envelope: Decodable { let updates: [AppUpdate] }
            if let env = try? JSONDecoder().decode(Envelope.self, from: data) {
                return env.updates
            }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - View

struct AppUpdatesSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = AppUpdatesLoader()

    var body: some View {
        // Intentionally no NavigationStack: the sheet is dismissed via the
        // drag indicator, so wrapping the content in a nav bar only added
        // a back/title chrome the user doesn't need.
        ZStack {
            viewState.theme.background.color.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("What's New")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(viewState.theme.foreground.color)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

                Group {
                    switch loader.phase {
                    case .idle, .loading:
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .tint(viewState.theme.accent.color)
                        Spacer()
                    case .failed(let message):
                        Spacer()
                        emptyState(title: "Couldn't load updates", message: message, systemImage: "exclamationmark.triangle")
                        Spacer()
                    case .loaded(let items) where items.isEmpty:
                        Spacer()
                        emptyState(title: "You're all caught up", message: "No new announcements yet. Check back soon.", systemImage: "sparkles")
                        Spacer()
                    case .loaded(let items):
                        list(items)
                    }
                }
            }
        }
        .task { await loader.load() }
    }

    @ViewBuilder
    private func list(_ items: [AppUpdate]) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(items) { item in
                    UpdateCard(update: item)
                }
            }
            .padding(16)
        }
        .refreshable { await loader.load(force: true) }
    }

    @ViewBuilder
    private func emptyState(title: String, message: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(viewState.theme.accent.color.opacity(0.6))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(viewState.theme.foreground.color)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(viewState.theme.foreground3.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Row

private struct UpdateCard: View {
    @EnvironmentObject var viewState: AppViewState
    let update: AppUpdate

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlString = update.image_url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(viewState.theme.background2.color)
                            .overlay(ProgressView().tint(viewState.theme.accent.color))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(viewState.theme.background2.color)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundStyle(viewState.theme.foreground3.color)
                            )
                    @unknown default:
                        Color.clear
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let tag = update.tag, !tag.isEmpty {
                        Text(tag.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(viewState.theme.accent.color.opacity(0.18))
                            )
                            .foregroundStyle(viewState.theme.accent.color)
                    }

                    if let date = update.publishedDate {
                        Text(Self.relativeFormatter.localizedString(for: date, relativeTo: .now))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }

                    Spacer(minLength: 0)
                }

                Text(update.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(viewState.theme.foreground.color)

                if let desc = update.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(viewState.theme.foreground2.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(viewState.theme.background2.color)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
