//
//  HeartRateTimeline.swift
//  SPAJAM2026App
//
//  リザルト「ドキドキ ログ」の集計。旅の時間帯を等間隔の区間に分け、区間ごとの最大心拍を
//  折れ線グラフの点にする。ミッション達成時刻も同じ時間軸に乗せ、バーとミッション写真を同期させる。
//  心拍が最も高かった時刻に近いミッション(peakMissionIds)を求め、バー上のピンに使う。
//  HealthKit / Watch に依存しない純粋な値型(ユニットテスト対象)。
//

import Foundation

nonisolated struct HeartRateTimeline: Sendable, Equatable {
    /// 時間帯 1 区間分の値(折れ線グラフの 1 点)
    struct Bar: Sendable, Equatable, Identifiable {
        var index: Int
        /// 区間の最大心拍。サンプルが無い区間は前後から補間した値
        var bpm: Double
        /// 0...1 に正規化した高さ(最小 0・最大 1。全区間同じ値なら 0.5)
        var level: Double
        /// 実サンプルがある区間か
        var hasSamples: Bool

        var id: Int { index }
    }

    /// 時間軸上に乗せたミッション達成
    struct Marker: Sendable, Equatable, Identifiable {
        var missionId: String
        var achievedAt: Date
        /// 旅の時間帯での位置(0...1)
        var position: Double
        /// 対応するバーの index
        var barIndex: Int

        var id: String { missionId }
    }

    /// バー上のピン(自分の最高心拍・他の参加者の最高心拍・自分の 2 番目)
    struct Pin: Sendable, Equatable, Identifiable {
        enum Kind: Sendable, Equatable {
            /// 自分の心拍が最も高かった時刻に近いミッション(大きいピン・大きい写真)
            case main
            /// 自分の心拍が 2 番目に高かった時刻に近いミッション
            case second
            /// 他の参加者の最高心拍に近いミッション(ハート型ピン + アイコン)
            case other(name: String)
        }

        var id: String
        var missionId: String
        var achievedAt: Date
        /// 旅の時間帯での位置(0...1)
        var position: Double
        /// 対応するバーの index
        var barIndex: Int
        var kind: Kind

        var isMain: Bool { kind == .main }
    }

    /// 他の参加者が共有してきた最高心拍ミッション
    struct OtherPeak: Sendable, Equatable {
        var id: String
        var name: String
        var missionId: String
        var achievedAt: Date
    }

    let interval: DateInterval
    let bars: [Bar]
    let markers: [Marker]
    /// 旅全体の平均心拍(サンプルが無ければ nil)
    let averageBpm: Double?
    /// 最高心拍(サンプルが無ければ nil)
    let maximumBpm: Double?
    /// 心が動いた(急上昇した)回数
    let spikeCount: Int
    /// 心拍が高かった時刻に近いミッション(高い順・重複なし、最大 2 件)。サンプルか達成ログが無ければ空
    let peakMissionIds: [String]

    private let barCount: Int

    /// 自分の最高心拍に近いミッション
    var peakMissionId: String? { peakMissionIds.first }

    /// 旅の時間帯での位置(0...1)。範囲外は端に寄せる
    func position(of date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(interval.start) / max(interval.duration, 1)))
    }

    /// 旅の時間帯での位置(0...1)を時刻に戻す。範囲外は端に寄せる
    func date(at position: Double) -> Date {
        interval.start.addingTimeInterval(min(1, max(0, position)) * interval.duration)
    }

    /// `date` が入るバーの index
    func barIndex(of date: Date) -> Int {
        min(barCount - 1, Int(position(of: date) * Double(barCount)))
    }

    /// 最も心拍が高い区間
    var peakBar: Bar? { bars.max { $0.bpm < $1.bpm } }

    var hasSamples: Bool { bars.contains(where: \.hasSamples) }

    /// `barIndex` に最も近いマーカー
    func marker(nearestTo barIndex: Int) -> Marker? {
        markers.min { abs($0.barIndex - barIndex) < abs($1.barIndex - barIndex) }
    }

    /// - Parameters:
    ///   - samples: 自分の心拍サンプル(順不同可)
    ///   - records: ミッション達成ログ
    ///   - interval: 旅の時間帯。nil ならサンプルと達成時刻から推定する
    ///   - barCount: バーの本数
    ///   - spikeThreshold: 直近平均からこの値以上上がったら「心が動いた」
    ///   - spikeCooldown: 連続検出を抑える間隔(秒)
    init(
        samples: [HeartRateSample],
        records: [MissionRecord],
        interval: DateInterval?,
        barCount: Int = 12,
        spikeThreshold: Double = 15,
        spikeCooldown: TimeInterval = 180
    ) {
        let barCount = max(1, barCount)
        let sorted = samples.filter { $0.bpm.isFinite && $0.bpm > 0 }.sorted { $0.date < $1.date }
        let interval = interval ?? Self.estimateInterval(samples: sorted, records: records)
        self.interval = interval
        self.barCount = barCount
        let duration = max(interval.duration, 1)

        func position(of date: Date) -> Double {
            min(1, max(0, date.timeIntervalSince(interval.start) / duration))
        }
        func barIndex(of date: Date) -> Int {
            min(barCount - 1, Int(position(of: date) * Double(barCount)))
        }

        // 区間ごとの最大
        var values = [Double?](repeating: nil, count: barCount)
        var counts = [Int](repeating: 0, count: barCount)
        for sample in sorted {
            let i = barIndex(of: sample.date)
            values[i] = max(values[i] ?? sample.bpm, sample.bpm)
            counts[i] += 1
        }
        // 空区間は前後の実測値で線形補間(端は最寄りの値)
        let known = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        if !known.isEmpty {
            for i in 0..<barCount where values[i] == nil {
                let before = known.last { $0.0 < i }
                let after = known.first { $0.0 > i }
                switch (before, after) {
                case let (b?, a?):
                    let t = Double(i - b.0) / Double(a.0 - b.0)
                    values[i] = b.1 + (a.1 - b.1) * t
                case let (b?, nil): values[i] = b.1
                case let (nil, a?): values[i] = a.1
                default: break
                }
            }
        }

        let filled = values.map { $0 ?? 0 }
        let minBpm = filled.min() ?? 0
        let maxBpm = filled.max() ?? 0
        let range = maxBpm - minBpm
        bars = (0..<barCount).map { i in
            let level: Double = known.isEmpty ? 0 : (range < 1 ? 0.5 : (filled[i] - minBpm) / range)
            return Bar(index: i, bpm: filled[i], level: level, hasSamples: counts[i] > 0)
        }

        markers = records
            .sorted { $0.achievedAt < $1.achievedAt }
            .map { Marker(missionId: $0.missionId, achievedAt: $0.achievedAt, position: position(of: $0.achievedAt), barIndex: barIndex(of: $0.achievedAt)) }

        let all = sorted.map(\.bpm)
        averageBpm = all.isEmpty ? nil : all.reduce(0, +) / Double(all.count)
        maximumBpm = all.max()
        spikeCount = Self.countSpikes(sorted, threshold: spikeThreshold, cooldown: spikeCooldown)
        peakMissionIds = Self.peakMissionIds(samples: sorted, records: records, limit: 2)
    }

    /// 心拍の高いサンプルから順に、達成時刻が最も近いミッションを拾う(同じミッションは 1 回だけ)
    static func peakMissionIds(samples: [HeartRateSample], records: [MissionRecord], limit: Int) -> [String] {
        guard !records.isEmpty, limit > 0 else { return [] }
        var ids: [String] = []
        for sample in samples.sorted(by: { $0.bpm > $1.bpm }) {
            guard let nearest = records.min(by: {
                abs($0.achievedAt.timeIntervalSince(sample.date)) < abs($1.achievedAt.timeIntervalSince(sample.date))
            }) else { break }
            if !ids.contains(nearest.missionId) { ids.append(nearest.missionId) }
            if ids.count >= limit { break }
        }
        return ids
    }

    /// バー上に並べるピンを組み立てる(時間順)。
    /// - 自分の最高心拍に近いミッション → `.main`
    /// - 他の参加者の最高心拍に近いミッション → `.other`
    /// - 参加者が自分を含めて 2 人以下なら、自分の 2 番目に高かったミッション → `.second`
    func pins(records: [MissionRecord], others: [OtherPeak]) -> [Pin] {
        var pins: [Pin] = []
        func record(for missionId: String) -> MissionRecord? {
            records.first { $0.missionId == missionId }
        }
        if let main = peakMissionIds.first, let record = record(for: main) {
            pins.append(Pin(id: "me:\(main)", missionId: main, achievedAt: record.achievedAt,
                            position: position(of: record.achievedAt), barIndex: barIndex(of: record.achievedAt), kind: .main))
        }
        for other in others {
            pins.append(Pin(id: "other:\(other.id)", missionId: other.missionId, achievedAt: other.achievedAt,
                            position: position(of: other.achievedAt), barIndex: barIndex(of: other.achievedAt), kind: .other(name: other.name)))
        }
        let partyCount = 1 + others.count
        if partyCount <= 2, peakMissionIds.count >= 2, let record = record(for: peakMissionIds[1]) {
            let id = peakMissionIds[1]
            pins.append(Pin(id: "me2:\(id)", missionId: id, achievedAt: record.achievedAt,
                            position: position(of: record.achievedAt), barIndex: barIndex(of: record.achievedAt), kind: .second))
        }
        return pins.sorted { $0.position < $1.position }
    }

    /// TripSession.checkHeartSpike と同じ条件で、履歴を通しで数える
    static func countSpikes(_ sorted: [HeartRateSample], threshold: Double, cooldown: TimeInterval) -> Int {
        var count = 0
        var lastSpike: Date?
        for (i, sample) in sorted.enumerated() {
            let history = sorted[..<i].suffix(20).map(\.bpm)
            guard history.count >= 5 else { continue }
            let average = history.reduce(0, +) / Double(history.count)
            guard sample.bpm - average >= threshold else { continue }
            if let lastSpike, sample.date.timeIntervalSince(lastSpike) < cooldown { continue }
            lastSpike = sample.date
            count += 1
        }
        return count
    }

    private static func estimateInterval(samples: [HeartRateSample], records: [MissionRecord]) -> DateInterval {
        let dates = samples.map(\.date) + records.map(\.achievedAt)
        guard let first = dates.min(), let last = dates.max() else {
            return DateInterval(start: Date(), duration: 3600)
        }
        // 両端に 10 分の余白
        return DateInterval(start: first.addingTimeInterval(-600), end: last.addingTimeInterval(600))
    }
}

extension HeartRateTimeline {
    /// デモ用: サンプルが無いときに見せる波形(ミッション達成のあたりで盛り上がる)
    static func demoSamples(records: [MissionRecord], interval: DateInterval) -> [HeartRateSample] {
        let step: TimeInterval = max(30, interval.duration / 120)
        var samples: [HeartRateSample] = []
        var t = interval.start
        var seed: UInt64 = 0x9E37_79B9
        while t <= interval.end {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = Double(seed >> 40 % 1000) / 1000 * 6 - 3
            var bpm = 78 + noise
            for record in records {
                let d = abs(record.achievedAt.timeIntervalSince(t))
                if d < 240 { bpm += 28 * (1 - d / 240) }
            }
            samples.append(HeartRateSample(date: t, bpm: bpm))
            t = t.addingTimeInterval(step)
        }
        return samples
    }
}

extension TripSession {
    /// リザルトで使う、自分の心拍だけで組み立てた時間軸。サンプルが少なければデモ波形で埋める
    var resultTimeline: HeartRateTimeline {
        let interval = tripInterval
        var samples = heartRateSamples
        if samples.count < 3 {
            let demoInterval = interval ?? HeartRateTimeline(samples: [], records: records, interval: nil).interval
            samples = HeartRateTimeline.demoSamples(records: records, interval: demoInterval)
        }
        return HeartRateTimeline(samples: samples, records: records, interval: interval)
    }
}
