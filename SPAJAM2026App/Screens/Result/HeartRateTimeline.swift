//
//  HeartRateTimeline.swift
//  SPAJAM2026App
//
//  リザルト「ドキドキ ログ」の集計。旅の時間帯を等間隔の区間に分け、区間ごとの平均心拍を
//  横並びのバーにする。ミッション達成時刻も同じ時間軸に乗せ、バーとミッション写真を同期させる。
//  HealthKit / Watch に依存しない純粋な値型(ユニットテスト対象)。
//

import Foundation

nonisolated struct HeartRateTimeline: Sendable, Equatable {
    /// 時間帯 1 区間分のバー
    struct Bar: Sendable, Equatable, Identifiable {
        var index: Int
        /// 区間の平均心拍。サンプルが無い区間は前後から補間した値
        var bpm: Double
        /// 0...1 に正規化した高さ
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

    let interval: DateInterval
    let bars: [Bar]
    let markers: [Marker]
    /// 旅全体の平均心拍(サンプルが無ければ nil)
    let averageBpm: Double?
    /// 最高心拍(サンプルが無ければ nil)
    let maximumBpm: Double?
    /// 心が動いた(急上昇した)回数
    let spikeCount: Int

    /// 最も心拍が高い区間
    var peakBar: Bar? { bars.max { $0.bpm < $1.bpm } }

    /// 最高心拍の平均からの上がり幅(bpm)
    var peakDelta: Int? {
        guard let maximumBpm, let averageBpm else { return nil }
        return Int((maximumBpm - averageBpm).rounded())
    }

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
        let duration = max(interval.duration, 1)

        func position(of date: Date) -> Double {
            min(1, max(0, date.timeIntervalSince(interval.start) / duration))
        }
        func barIndex(of date: Date) -> Int {
            min(barCount - 1, Int(position(of: date) * Double(barCount)))
        }

        // 区間ごとの平均
        var sums = [Double](repeating: 0, count: barCount)
        var counts = [Int](repeating: 0, count: barCount)
        for sample in sorted {
            let i = barIndex(of: sample.date)
            sums[i] += sample.bpm
            counts[i] += 1
        }
        var means: [Double?] = (0..<barCount).map { counts[$0] > 0 ? sums[$0] / Double(counts[$0]) : nil }
        // 空区間は前後の実測値で線形補間(端は最寄りの値)
        let known = means.enumerated().compactMap { i, v in v.map { (i, $0) } }
        if !known.isEmpty {
            for i in 0..<barCount where means[i] == nil {
                let before = known.last { $0.0 < i }
                let after = known.first { $0.0 > i }
                switch (before, after) {
                case let (b?, a?):
                    let t = Double(i - b.0) / Double(a.0 - b.0)
                    means[i] = b.1 + (a.1 - b.1) * t
                case let (b?, nil): means[i] = b.1
                case let (nil, a?): means[i] = a.1
                default: break
                }
            }
        }

        let values = means.map { $0 ?? 0 }
        let minBpm = values.min() ?? 0
        let maxBpm = values.max() ?? 0
        let range = maxBpm - minBpm
        bars = (0..<barCount).map { i in
            let level: Double = known.isEmpty ? 0 : (range < 1 ? 0.6 : 0.2 + 0.8 * (values[i] - minBpm) / range)
            return Bar(index: i, bpm: values[i], level: level, hasSamples: counts[i] > 0)
        }

        markers = records
            .sorted { $0.achievedAt < $1.achievedAt }
            .map { Marker(missionId: $0.missionId, achievedAt: $0.achievedAt, position: position(of: $0.achievedAt), barIndex: barIndex(of: $0.achievedAt)) }

        let all = sorted.map(\.bpm)
        averageBpm = all.isEmpty ? nil : all.reduce(0, +) / Double(all.count)
        maximumBpm = all.max()
        spikeCount = Self.countSpikes(sorted, threshold: spikeThreshold, cooldown: spikeCooldown)
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
