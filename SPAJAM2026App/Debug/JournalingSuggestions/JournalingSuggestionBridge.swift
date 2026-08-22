//
//  JournalingSuggestionBridge.swift
//  SPAJAM2026App
//
//  Converts a `JournalingSuggestion` handed back by the system picker into the
//  plain `SuggestionEntry` model the UI renders.
//
//  The JournalingSuggestions framework ships only on device, so everything here
//  is compiled out for the simulator (see SampleSuggestions for the stand-in).
//

#if canImport(JournalingSuggestions)

import CoreLocation
import Foundation
import HealthKit
import JournalingSuggestions

extension SuggestionEntry {
    init(suggestion: JournalingSuggestion) async {
        var resolved: [SuggestionItem] = []
        resolved.reserveCapacity(suggestion.items.count)
        for item in suggestion.items {
            resolved.append(await SuggestionItem(item: item))
        }
        self.init(
            id: UUID(),
            title: suggestion.title,
            dateInterval: suggestion.date,
            pickedAt: .now,
            items: resolved
        )
    }
}

extension SuggestionItem {
    init(item: JournalingSuggestion.ItemContent) async {
        if item.hasContent(ofType: JournalingSuggestion.Photo.self),
           let photo = try? await item.content(forType: JournalingSuggestion.Photo.self) {
            self.init(
                id: item.id,
                kind: .photo,
                headline: "写真",
                details: [photo.date.map { "撮影: \(SuggestionFormat.date($0))" }].compactMap { $0 },
                imageURL: photo.photo
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.LivePhoto.self),
           let live = try? await item.content(forType: JournalingSuggestion.LivePhoto.self) {
            self.init(
                id: item.id,
                kind: .livePhoto,
                headline: "Live Photo",
                details: [live.date.map { "撮影: \(SuggestionFormat.date($0))" }].compactMap { $0 },
                imageURL: live.image
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Video.self),
           let video = try? await item.content(forType: JournalingSuggestion.Video.self) {
            self.init(
                id: item.id,
                kind: .video,
                headline: video.url.lastPathComponent,
                details: [video.date.map { "撮影: \(SuggestionFormat.date($0))" }].compactMap { $0 }
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Song.self),
           let song = try? await item.content(forType: JournalingSuggestion.Song.self) {
            self.init(
                id: item.id,
                kind: .song,
                headline: song.song ?? "不明な曲",
                details: [
                    song.artist,
                    song.album,
                    song.date.map { "再生: \(SuggestionFormat.date($0))" }
                ].compactMap { $0 },
                imageURL: song.artwork
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Podcast.self),
           let podcast = try? await item.content(forType: JournalingSuggestion.Podcast.self) {
            self.init(
                id: item.id,
                kind: .podcast,
                headline: podcast.episode ?? "不明なエピソード",
                details: [
                    podcast.show,
                    podcast.date.map { "再生: \(SuggestionFormat.date($0))" }
                ].compactMap { $0 },
                imageURL: podcast.artwork
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.GenericMedia.self),
           let media = try? await item.content(forType: JournalingSuggestion.GenericMedia.self) {
            self.init(
                id: item.id,
                kind: .media,
                headline: media.title ?? "不明なメディア",
                details: [
                    media.artist,
                    media.album,
                    media.date.map { "再生: \(SuggestionFormat.date($0))" }
                ].compactMap { $0 },
                imageURL: media.appIcon
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Contact.self),
           let contact = try? await item.content(forType: JournalingSuggestion.Contact.self) {
            self.init(
                id: item.id,
                kind: .contact,
                headline: contact.name,
                imageURL: contact.photo
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.LocationGroup.self),
           let group = try? await item.content(forType: JournalingSuggestion.LocationGroup.self) {
            self.init(
                id: item.id,
                kind: .locationGroup,
                headline: "\(group.locations.count) 件の場所",
                details: group.locations.prefix(5).map { location in
                    [location.place, location.city].compactMap { $0 }.joined(separator: ", ")
                }
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Location.self),
           let location = try? await item.content(forType: JournalingSuggestion.Location.self) {
            self.init(
                id: item.id,
                kind: .location,
                headline: location.place ?? location.city ?? "不明な場所",
                details: [
                    location.city,
                    location.location.map { coordinate in
                        String(
                            format: "%.4f, %.4f",
                            coordinate.coordinate.latitude,
                            coordinate.coordinate.longitude
                        )
                    },
                    location.date.map { "訪問: \(SuggestionFormat.date($0))" }
                ].compactMap { $0 }
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.WorkoutGroup.self),
           let group = try? await item.content(forType: JournalingSuggestion.WorkoutGroup.self) {
            self.init(
                id: item.id,
                kind: .workoutGroup,
                headline: "\(group.workouts.count) 件のワークアウト",
                details: [
                    group.duration.map { "合計時間: \(SuggestionFormat.duration($0))" },
                    group.activeEnergyBurned.flatMap(Self.energyText),
                    group.averageHeartRate.flatMap(Self.heartRateText)
                ].compactMap { $0 },
                imageURL: group.icon
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Workout.self),
           let workout = try? await item.content(forType: JournalingSuggestion.Workout.self) {
            let details = workout.details
            self.init(
                id: item.id,
                kind: .workout,
                headline: details?.localizedName ?? "ワークアウト",
                details: [
                    details?.date.map { SuggestionFormat.interval($0) },
                    details?.distance.flatMap(Self.distanceText),
                    details?.activeEnergyBurned.flatMap(Self.energyText),
                    details?.averageHeartRate.flatMap(Self.heartRateText),
                    workout.route.map { "ルート: \($0.count) 点" }
                ].compactMap { $0 },
                imageURL: workout.icon
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.MotionActivity.self),
           let motion = try? await item.content(forType: JournalingSuggestion.MotionActivity.self) {
            self.init(
                id: item.id,
                kind: .motionActivity,
                headline: "\(motion.steps) 歩",
                details: [motion.date.map { SuggestionFormat.interval($0) }].compactMap { $0 },
                imageURL: motion.icon
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.StateOfMind.self),
           let state = try? await item.content(forType: JournalingSuggestion.StateOfMind.self) {
            self.init(
                id: item.id,
                kind: .stateOfMind,
                headline: String(format: "快適さ %.2f", state.state.valence),
                details: [
                    "種別: \(state.state.kind == .dailyMood ? "1日の気分" : "その時の感情")",
                    "ラベル: \(state.state.labels.count) 件"
                ],
                imageURL: state.icon
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.Reflection.self),
           let reflection = try? await item.content(forType: JournalingSuggestion.Reflection.self) {
            self.init(
                id: item.id,
                kind: .reflection,
                headline: reflection.prompt
            )
            return
        }

        if item.hasContent(ofType: JournalingSuggestion.EventPoster.self),
           let event = try? await item.content(forType: JournalingSuggestion.EventPoster.self) {
            self.init(
                id: item.id,
                kind: .eventPoster,
                headline: String(event.title.characters),
                details: [
                    event.placeName,
                    event.eventStart.map { "開始: \(SuggestionFormat.date($0))" },
                    event.eventEnd.map { "終了: \(SuggestionFormat.date($0))" },
                    event.isHost.map { $0 ? "主催者" : "参加者" }
                ].compactMap { $0 },
                imageURL: event.image
            )
            return
        }

        self.init(
            id: item.id,
            kind: .unknown,
            headline: "表示できないコンテンツ",
            details: ["representations: \(item.representations.count) 件"]
        )
    }

    // MARK: - HealthKit quantity formatting

    private static func energyText(_ quantity: HKQuantity) -> String? {
        let unit = HKUnit.kilocalorie()
        guard quantity.is(compatibleWith: unit) else { return nil }
        return "消費エネルギー: \(Int(quantity.doubleValue(for: unit).rounded())) kcal"
    }

    private static func distanceText(_ quantity: HKQuantity) -> String? {
        let unit = HKUnit.meter()
        guard quantity.is(compatibleWith: unit) else { return nil }
        let meters = quantity.doubleValue(for: unit)
        return meters >= 1000
            ? String(format: "距離: %.2f km", meters / 1000)
            : "距離: \(Int(meters.rounded())) m"
    }

    private static func heartRateText(_ quantity: HKQuantity) -> String? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard quantity.is(compatibleWith: unit) else { return nil }
        return "平均心拍数: \(Int(quantity.doubleValue(for: unit).rounded())) bpm"
    }
}

#endif
