//
//  MemoryEntry.swift
//  SPAJAM2026App
//
//  リザルトの「思い出カルーセル ↔ 心拍グラフ」で扱う 1 枚分の項目。
//  自分のミッション達成写真と、みんなの「心が動いた瞬間」の写真を時系列(古い順)に並べる。
//  グラフのカーソルを項目に引っかける(スナップ)計算もここに置く。純粋な値型(ユニットテスト対象)。
//

import Foundation

nonisolated struct MemoryEntry: Sendable, Equatable, Identifiable {
    enum Kind: Sendable, Equatable {
        /// 自分のミッション達成(ピン)。`order` は MISSION 番号
        case mission(missionId: String, order: Int)
        /// 心が動いた瞬間(ハート)。`ownerName` は撮った人(自分なら nil)
        case heart(ownerName: String?)
    }

    var id: String
    var kind: Kind
    var date: Date
    /// 旅の時間帯での位置(0...1)
    var position: Double
    var bpm: Int?

    var isMission: Bool {
        if case .mission = kind { return true }
        return false
    }

    /// 写真の下に出すラベル
    var label: String {
        switch kind {
        case .mission(_, let order): "MISSION \(order)"
        case .heart: "心が動いた瞬間"
        }
    }

    /// 自分の写真か(他の参加者の「心が動いた瞬間」だけ false)
    var isMine: Bool {
        if case .heart(let owner) = kind { return owner == nil }
        return true
    }

    /// 他の参加者が撮った「心が動いた瞬間」
    struct OtherMoment: Sendable, Equatable {
        var id: String
        var ownerName: String
        var capturedAt: Date
        var bpm: Int?
    }

    /// 時系列(古い順)に並べた項目を組み立てる
    static func build(
        records: [MissionRecord],
        missions: [Mission],
        myMoments: [HeartMoment],
        otherMoments: [OtherMoment],
        timeline: HeartRateTimeline
    ) -> [MemoryEntry] {
        var entries: [MemoryEntry] = []
        for record in records {
            guard let mission = missions.first(where: { $0.id == record.missionId }) else { continue }
            entries.append(MemoryEntry(
                id: "mission:\(record.missionId)",
                kind: .mission(missionId: mission.id, order: mission.order),
                date: record.achievedAt,
                position: timeline.position(of: record.achievedAt),
                bpm: record.bpmAtAchieve
            ))
        }
        for moment in myMoments {
            entries.append(MemoryEntry(
                id: "moment:\(moment.id)",
                kind: .heart(ownerName: nil),
                date: moment.capturedAt,
                position: timeline.position(of: moment.capturedAt),
                bpm: moment.bpm
            ))
        }
        for moment in otherMoments {
            entries.append(MemoryEntry(
                id: "other:\(moment.id)",
                kind: .heart(ownerName: moment.ownerName),
                date: moment.capturedAt,
                position: timeline.position(of: moment.capturedAt),
                bpm: moment.bpm
            ))
        }
        return entries.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

extension Array where Element == MemoryEntry {
    /// `position` に最も近い項目
    func nearest(to position: Double) -> MemoryEntry? {
        self.min { abs($0.position - position) < abs($1.position - position) }
    }

    /// `position` から `radius` 以内にある最も近い項目(カーソルを引っかける用)。無ければ nil
    func snapTarget(for position: Double, radius: Double) -> MemoryEntry? {
        guard let nearest = nearest(to: position), abs(nearest.position - position) <= radius else { return nil }
        return nearest
    }

    /// カルーセルの連続的な index(1.5 なら項目 1 と 2 の中間)をグラフ位置(0...1)に変換する。
    /// 末尾→先頭のように循環して動いたときは、端から端へ線形に補間する
    func position(atFractionalIndex fractional: Double) -> Double {
        guard !isEmpty else { return 0 }
        let count = Double(self.count)
        let wrapped = ((fractional.truncatingRemainder(dividingBy: count)) + count).truncatingRemainder(dividingBy: count)
        let lower = Int(wrapped.rounded(.down)) % self.count
        let upper = (lower + 1) % self.count
        let t = wrapped - Double(lower)
        return self[lower].position + (self[upper].position - self[lower].position) * t
    }
}
