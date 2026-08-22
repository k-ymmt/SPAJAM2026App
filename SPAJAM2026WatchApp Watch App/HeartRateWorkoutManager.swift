//
//  HeartRateWorkoutManager.swift
//  SPAJAM2026WatchApp Watch App
//
//  Runs a HealthKit workout session so the watch samples heart rate
//  continuously, and streams each reading to the phone over WatchConnectivity.
//

import Foundation
import HealthKit
import Observation
import WatchConnectivity

@Observable
final class HeartRateWorkoutManager {
    private(set) var beatsPerMinute: Double?
    private(set) var isRunning = false
    private(set) var isPhoneReachable = false
    private(set) var errorMessage: String?

    private let store = HKHealthStore()
    private let relay = WorkoutRelay()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    init() {
        relay.onHeartRate = { [weak self] bpm, date in
            Task { @MainActor in self?.update(bpm: bpm, at: date) }
        }
        relay.onSessionEnded = { [weak self] in
            Task { @MainActor in self?.cleanUp() }
        }
        relay.onError = { [weak self] message in
            Task { @MainActor in self?.errorMessage = message }
        }
        relay.onCommand = { [weak self] command in
            Task { @MainActor in
                guard let self else { return }
                switch command {
                case .start: await self.start()
                case .stop: self.stop()
                }
            }
        }
        relay.onReachabilityChange = { [weak self] reachable in
            Task { @MainActor in self?.isPhoneReachable = reachable }
        }
        relay.activate()
    }

    func start() async {
        guard !isRunning else { return }
        errorMessage = nil
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit を利用できません"
            return
        }
        do {
            try await store.requestAuthorization(
                toShare: [HKQuantityType.workoutType()],
                read: [HKQuantityType(.heartRate)]
            )
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .other
            configuration.locationType = .unknown

            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = relay
            builder.delegate = relay
            self.session = session
            self.builder = builder

            let startDate = Date.now
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            isRunning = true
            relay.send(.streamingState(isActive: true))
        } catch {
            errorMessage = error.localizedDescription
            cleanUp()
        }
    }

    func stop() {
        guard isRunning, let session else { return }
        session.end()
        let builder = self.builder
        Task {
            try? await builder?.endCollection(at: .now)
            builder?.discardWorkout()
        }
        cleanUp()
    }

    private func update(bpm: Double, at date: Date) {
        beatsPerMinute = bpm
        relay.send(.heartRate(beatsPerMinute: bpm, timestamp: date))
    }

    private func cleanUp() {
        if isRunning {
            relay.send(.streamingState(isActive: false))
        }
        isRunning = false
        session = nil
        builder = nil
    }
}

/// Off-main-actor delegate object for HealthKit and WatchConnectivity callbacks.
nonisolated final class WorkoutRelay: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    var onHeartRate: (@Sendable (Double, Date) -> Void)?
    var onSessionEnded: (@Sendable () -> Void)?
    var onError: (@Sendable (String) -> Void)?
    var onCommand: (@Sendable (HeartRateMessage.Command) -> Void)?
    var onReachabilityChange: (@Sendable (Bool) -> Void)?

    private let heartRateType = HKQuantityType(.heartRate)
    private let unit = HKUnit.count().unitDivided(by: .minute())

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ message: HeartRateMessage) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(message.dictionary, replyHandler: nil)
        } else {
            // Keep the phone's last-known state fresh for when it reconnects.
            try? session.updateApplicationContext(message.dictionary)
        }
    }

    // MARK: HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended {
            onSessionEnded?()
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        onError?(error.localizedDescription)
        onSessionEnded?()
    }

    // MARK: HKLiveWorkoutBuilderDelegate

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity()
        else { return }
        let date = statistics.mostRecentQuantityDateInterval()?.end ?? .now
        onHeartRate?(quantity.doubleValue(for: unit), date)
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        onReachabilityChange?(session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard case let .command(command)? = HeartRateMessage(dictionary: message) else { return }
        onCommand?(command)
    }
}
