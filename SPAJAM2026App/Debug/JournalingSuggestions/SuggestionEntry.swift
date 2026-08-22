//
//  SuggestionEntry.swift
//  SPAJAM2026App
//
//  Framework-independent representation of a picked journaling suggestion.
//  Keeping it free of `import JournalingSuggestions` lets the whole UI build
//  for the simulator, where that framework does not exist.
//

import Foundation

struct SuggestionEntry: Identifiable, Hashable {
    let id: UUID
    let title: String
    let dateInterval: DateInterval?
    let pickedAt: Date
    let items: [SuggestionItem]

    init(
        id: UUID = UUID(),
        title: String,
        dateInterval: DateInterval? = nil,
        pickedAt: Date = .now,
        items: [SuggestionItem] = []
    ) {
        self.id = id
        self.title = title
        self.dateInterval = dateInterval
        self.pickedAt = pickedAt
        self.items = items
    }
}

struct SuggestionItem: Identifiable, Hashable {
    let id: UUID
    let kind: SuggestionItemKind
    let headline: String
    let details: [String]
    let imageURL: URL?

    init(
        id: UUID = UUID(),
        kind: SuggestionItemKind,
        headline: String,
        details: [String] = [],
        imageURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.details = details
        self.imageURL = imageURL
    }
}

enum SuggestionItemKind: String, CaseIterable, Hashable {
    case photo
    case video
    case livePhoto
    case song
    case podcast
    case media
    case contact
    case location
    case locationGroup
    case workout
    case workoutGroup
    case motionActivity
    case stateOfMind
    case reflection
    case eventPoster
    case unknown

    var symbolName: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        case .livePhoto: "livephoto"
        case .song: "music.note"
        case .podcast: "mic"
        case .media: "play.rectangle"
        case .contact: "person.crop.circle"
        case .location: "mappin.and.ellipse"
        case .locationGroup: "map"
        case .workout: "figure.run"
        case .workoutGroup: "figure.run.square.stack"
        case .motionActivity: "shoeprints.fill"
        case .stateOfMind: "brain.head.profile"
        case .reflection: "quote.bubble"
        case .eventPoster: "ticket"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .photo: "写真"
        case .video: "ビデオ"
        case .livePhoto: "Live Photo"
        case .song: "ミュージック"
        case .podcast: "ポッドキャスト"
        case .media: "メディア再生"
        case .contact: "連絡先"
        case .location: "場所"
        case .locationGroup: "場所グループ"
        case .workout: "ワークアウト"
        case .workoutGroup: "ワークアウトグループ"
        case .motionActivity: "アクティビティ"
        case .stateOfMind: "心の状態"
        case .reflection: "リフレクション"
        case .eventPoster: "イベント"
        case .unknown: "不明なコンテンツ"
        }
    }
}

// MARK: - Formatting helpers shared by the bridge and the UI

enum SuggestionFormat {
    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func interval(_ interval: DateInterval) -> String {
        if Calendar.current.isDate(interval.start, inSameDayAs: interval.end) {
            let day = interval.start.formatted(date: .abbreviated, time: .omitted)
            let start = interval.start.formatted(date: .omitted, time: .shortened)
            let end = interval.end.formatted(date: .omitted, time: .shortened)
            return interval.duration == 0 ? "\(day) \(start)" : "\(day) \(start) – \(end)"
        }
        return "\(date(interval.start)) – \(date(interval.end))"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
