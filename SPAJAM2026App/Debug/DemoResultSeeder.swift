//
//  DemoResultSeeder.swift
//  SPAJAM2026App
//
//  デモ用の「終了済みの旅」を保存セッションとして書き込む。
//  リザルト画面(開発中)が本物のデータとして表示でき、旅のうたの素材にもなる。
//  成功パターン(全ミッション達成)と、ほぼ失敗パターン(1 つだけ達成)の 2 種。
//  写真は本物が来るまでミザル素材で代用(mission-<id>.jpg として書き出し)。
//

import UIKit

enum DemoResultSeeder {
    enum Pattern {
        case success
        case failure
    }

    /// デモ結果を保存セッションとして書き込む(TripSessionStore.didChange は呼び出し側で通知)
    static func seed(_ pattern: Pattern) {
        let plan = TravelPlan.bundledDemoPlan()
        let now = Date()
        let start = now.addingTimeInterval(-4.5 * 3600) // 4 時間半の旅

        let achievedMissions: [Mission]
        switch pattern {
        case .success: achievedMissions = plan.missions
        case .failure: achievedMissions = Array(plan.missions.prefix(1)) // 雷門だけ
        }

        // 達成記録(時間を旅の中に散らし、写真は同梱素材から生成)
        let placeholderAssets = ["MizaruCharacter", "Mizarus2", "Mizarus3", "Mizarus4", "Mizarus5"]
        let comments = ["いい一枚!", "最高の赤!", "おいしそう!", "最高の表情!", "見つけたね!"]
        var records: [MissionRecord] = []
        for (index, mission) in achievedMissions.enumerated() {
            let achievedAt = start.addingTimeInterval(Double(index + 1) * 45 * 60)
            let photoName = writePlaceholderPhoto(
                assetName: placeholderAssets[index % placeholderAssets.count],
                missionId: mission.id
            )
            records.append(MissionRecord(
                missionId: mission.id,
                achievedAt: achievedAt,
                photoFileName: photoName,
                bpmAtAchieve: [92, 104, 98, 152, 121][index % 5],
                points: mission.points,
                aiComment: comments[index % comments.count]
            ))
        }

        // 「心が動いた瞬間」の写真: ミッションの合間に 2 枚(成功パターンのみ)
        var moments: [HeartMoment] = []
        if pattern == .success {
            for (index, offsetMinutes) in [70.0, 160.0].enumerated() {
                let id = "demo-moment-\(index + 1)"
                moments.append(HeartMoment(
                    id: id,
                    capturedAt: start.addingTimeInterval(offsetMinutes * 60),
                    bpm: [126, 139][index],
                    photoFileName: writePlaceholderPhoto(
                        assetName: ["MizaruActive", "MizaruMania"][index],
                        fileName: "moment-\(id).jpg"
                    )
                ))
            }
        }

        // 心拍サンプル: ベース 78bpm + 達成の瞬間に山を作る
        var samples: [HeartRateSample] = []
        let duration = now.timeIntervalSince(start)
        let step: TimeInterval = 120
        var t: TimeInterval = 0
        while t < duration {
            let date = start.addingTimeInterval(t)
            var bpm = 78 + Double.random(in: -4...4)
            for record in records {
                let distance = abs(record.achievedAt.timeIntervalSince(date))
                if distance < 8 * 60 {
                    bpm += Double(record.bpmAtAchieve ?? 100) * 0.5 * (1 - distance / (8 * 60))
                }
            }
            for moment in moments {
                let distance = abs(moment.capturedAt.timeIntervalSince(date))
                if distance < 6 * 60 {
                    bpm += Double(moment.bpm ?? 120) * 0.4 * (1 - distance / (6 * 60))
                }
            }
            samples.append(HeartRateSample(date: date, bpm: min(bpm, 168)))
            t += step
        }

        let snapshot = TripSessionSnapshot(
            plan: plan,
            phase: .finished,
            currentMissionId: nil,
            records: records,
            heartRateSamples: samples,
            useMockJudge: true,
            tripStartedAt: start,
            tripEndedAt: now,
            // 前面時間(スマホを見た時間): 成功は 9 分、失敗は 52 分
            foregroundSeconds: pattern == .success ? 9 * 60 : 52 * 60,
            becameActiveAt: nil,
            restrictionAdjustments: pattern == .success ? 0 : 2,
            shieldSelectionData: nil,
            savedAt: now,
            heartMoments: moments
        )
        TripSessionStore.save(snapshot)
    }

    /// ミザル素材をクリーム背景の JPEG にして写真ストアへ書き出す
    private static func writePlaceholderPhoto(assetName: String, missionId: String) -> String? {
        writePlaceholderPhoto(assetName: assetName, fileName: "mission-\(missionId).jpg")
    }

    private static func writePlaceholderPhoto(assetName: String, fileName name: String) -> String? {
        guard let source = UIImage(named: assetName) else { return nil }
        let size = CGSize(width: 900, height: 675)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.925, green: 0.933, blue: 0.906, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let scale = min((size.width - 160) / source.size.width, (size.height - 120) / source.size.height)
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width, height: drawSize.height
            ))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: URL.documentsDirectory.appending(path: name))
        return name
    }
}
