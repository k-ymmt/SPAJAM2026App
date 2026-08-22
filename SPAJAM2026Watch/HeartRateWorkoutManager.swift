//
//  HeartRateWorkoutManager.swift
//  SPAJAM2026Watch
//
//  HKWorkoutSession + HKLiveWorkoutBuilder で心拍をほぼリアルタイムに取得する。
//

import Foundation
import HealthKit
import os

nonisolated private let logger = Logger(subsystem: "app.kymmt.SPAJAM2026App.watchkitapp", category: "HeartRate")

@MainActor
@Observable
final class HeartRateWorkoutManager {
    enum Status: Equatable {
        case idle
        case starting
        case measuring
        case stopping
    }

    private(set) var status: Status = .idle
    private(set) var beatsPerMinute: Double?
    private(set) var lastUpdatedAt: Date?
    private(set) var errorMessage: String?

    var isActive: Bool { status == .starting || status == .measuring }

    private let healthStore = HKHealthStore()
    private let sender: PhoneHeartRateSender
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var observer: WorkoutObserver?

    init(sender: PhoneHeartRateSender) {
        self.sender = sender
    }

    func toggle() async {
        if isActive {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard status == .idle else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "この端末では HealthKit を利用できません"
            return
        }

        status = .starting
        errorMessage = nil

        do {
            try await requestAuthorization()
            try startWorkout()
        } catch {
            logger.error("計測開始に失敗: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            status = .idle
        }
    }

    func stop() {
        guard isActive, let session else { return }
        status = .stopping
        session.end()
    }

    // MARK: - HealthKit

    private func requestAuthorization() async throws {
        // ワークアウトセッションを走らせるので workout の書き込み権限も必要。
        try await healthStore.requestAuthorization(
            toShare: [HKQuantityType.workoutType()],
            read: [HKQuantityType(.heartRate)]
        )
    }

    private func startWorkout() throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        let observer = WorkoutObserver(handlers: WorkoutObserver.Handlers(
            heartRate: { [weak self] bpm, date in
                guard let self else { return }
                Task { @MainActor in self.handle(beatsPerMinute: bpm, measuredAt: date) }
            },
            sessionState: { [weak self] state in
                guard let self else { return }
                Task { @MainActor in self.handle(sessionState: state) }
            },
            failure: { [weak self] error in
                guard let self else { return }
                Task { @MainActor in self.handle(failure: error) }
            }
        ))
        session.delegate = observer
        builder.delegate = observer

        self.session = session
        self.builder = builder
        self.observer = observer

        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { [weak self] _, error in
            guard let self, let error else { return }
            Task { @MainActor in self.handle(failure: error) }
        }
    }

    // MARK: - コールバック処理 (すべて MainActor 上)

    private func handle(beatsPerMinute bpm: Double, measuredAt date: Date) {
        guard isActive else { return }
        beatsPerMinute = bpm
        lastUpdatedAt = date
        sender.send(HeartRateUpdate(beatsPerMinute: bpm, measuredAt: date, isMeasuring: true))
    }

    private func handle(sessionState state: HKWorkoutSessionState) {
        switch state {
        case .running:
            status = .measuring
            sender.send(HeartRateUpdate(beatsPerMinute: beatsPerMinute, measuredAt: Date(), isMeasuring: true))
        case .ended:
            tearDown()
        default:
            break
        }
    }

    private func handle(failure error: any Error) {
        logger.error("ワークアウトセッションのエラー: \(error.localizedDescription, privacy: .public)")
        errorMessage = error.localizedDescription
        tearDown()
    }

    /// セッションを破棄する。ワークアウト自体はヘルスケアに保存せず破棄する。
    private func tearDown() {
        let builder = self.builder
        session?.delegate = nil
        builder?.delegate = nil
        self.session = nil
        self.builder = nil
        self.observer = nil

        status = .idle
        beatsPerMinute = nil
        lastUpdatedAt = nil
        sender.send(.stopped())

        guard let builder else { return }
        builder.endCollection(withEnd: Date()) { _, error in
            if let error {
                logger.error("endCollection 失敗: \(error.localizedDescription, privacy: .public)")
            }
            builder.discardWorkout()
        }
    }
}

/// HealthKit のデリゲートは任意のスレッドから呼ばれるため、MainActor から切り離して受け取る。
private nonisolated final class WorkoutObserver: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    struct Handlers: Sendable {
        let heartRate: @Sendable (Double, Date) -> Void
        let sessionState: @Sendable (HKWorkoutSessionState) -> Void
        let failure: @Sendable (any Error) -> Void
    }

    private let handlers: Handlers
    private let beatsPerMinuteUnit = HKUnit.count().unitDivided(by: .minute())

    init(handlers: Handlers) {
        self.handlers = handlers
        super.init()
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        handlers.sessionState(toState)
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        handlers.failure(error)
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity()
        else { return }

        let bpm = quantity.doubleValue(for: beatsPerMinuteUnit)
        let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
        handlers.heartRate(bpm, date)
    }
}
