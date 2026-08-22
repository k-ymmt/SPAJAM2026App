//
//  HealthKitHeartRateSource.swift
//  SPAJAM2026App
//
//  Fallback feed: observes heart rate samples that reach the phone's HealthKit
//  store (e.g. synced from a watch even when our watch app is not running).
//

import Foundation
import HealthKit

nonisolated final class HealthKitHeartRateSource {
    enum Authorization: Sendable, Equatable {
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    var onSample: (@Sendable (HeartRateSample) -> Void)?

    private let store = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)
    private let unit = HKUnit.count().unitDivided(by: .minute())
    private var query: HKAnchoredObjectQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Authorization {
        guard isAvailable else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: [], read: [heartRateType])
        } catch {
            return .denied
        }
        // Read permissions are not disclosed by HealthKit; the query simply
        // returns nothing if the user declined.
        return .authorized
    }

    /// Streams samples recorded after `since`.
    func start(since: Date) {
        guard isAvailable, query == nil else { return }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, (any Error)?) -> Void = { [weak self] _, samples, _, _, _ in
            guard let self, let quantities = samples as? [HKQuantitySample] else { return }
            for quantity in quantities {
                let sample = HeartRateSample(
                    timestamp: quantity.endDate,
                    beatsPerMinute: quantity.quantity.doubleValue(for: self.unit),
                    source: .health
                )
                self.onSample?(sample)
            }
        }
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        self.query = query
        store.execute(query)
    }

    func stop() {
        if let query {
            store.stop(query)
        }
        query = nil
    }
}
