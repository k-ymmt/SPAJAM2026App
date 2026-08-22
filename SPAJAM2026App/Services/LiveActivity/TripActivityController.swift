//
//  TripActivityController.swift
//  SPAJAM2026App
//
//  旅行中の Live Activity の開始・更新・終了。
//  表示は山本さん実装の TABI MISSION Live Activity(MissionActivityAttributes /
//  SPAJAM2026AppWidgets の MissionLiveActivity)を使用する。
//  location 指定のあるミッションでは目的地の地図スナップショットを App Group に書き、
//  ファイル名を ContentState で渡してカード内に案内マップを表示する。
//

import ActivityKit
import CoreLocation
import Foundation
import MapKit
import UIKit

@MainActor
final class TripActivityController {
    private var activity: Activity<MissionActivityAttributes>?

    // マップスナップショットの状態(ミッションごとに生成、移動したら更新)
    private var mapFileName: String?
    private var mapMissionId: String?
    private var mapRenderedAt: Date?
    private var mapRenderedLocation: CLLocation?
    private var isRenderingMap = false

    func start(plan: TravelPlan, mission: Mission) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }
        let attributes = MissionActivityAttributes(
            brandName: "TABI MISSION",
            iconSymbol: "safari.fill",
            planTitle: plan.title
        )
        let state = contentState(mission: mission, total: plan.missions.count, achievedCount: 0, distanceMeters: nil, bpm: nil)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    /// キル後の復元: OS 側に残っている Live Activity があれば再接続し、なければ新規に開始する
    func resume(plan: TravelPlan, mission: Mission) {
        if let existing = Activity<MissionActivityAttributes>.activities.first {
            activity = existing
        } else {
            start(plan: plan, mission: mission)
        }
    }

    func update(
        mission: Mission,
        total: Int,
        achievedCount: Int,
        distanceMeters: Double?,
        bpm: Double?,
        currentLocation: CLLocation? = nil
    ) {
        guard let activity else { return }
        let state = contentState(
            mission: mission,
            total: total,
            achievedCount: achievedCount,
            distanceMeters: distanceMeters,
            bpm: bpm
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
        renderMapIfNeeded(
            mission: mission, total: total, achievedCount: achievedCount,
            distanceMeters: distanceMeters, bpm: bpm, currentLocation: currentLocation
        )
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        mapFileName = nil
        mapMissionId = nil
        mapRenderedAt = nil
        mapRenderedLocation = nil
    }

    private func contentState(
        mission: Mission,
        total: Int,
        achievedCount: Int,
        distanceMeters: Double?,
        bpm: Double?
    ) -> MissionActivityAttributes.ContentState {
        .init(
            missionNumber: mission.order,
            missionTotal: total,
            missionText: mission.title,
            landmarkName: mission.judgment.location?.name ?? "目的地",
            distanceMeters: distanceMeters,
            heartRate: bpm,
            indicator: MissionIndicator(segmentCount: total, completedCount: achievedCount),
            updatedAt: Date(),
            mapImageFileName: mission.judgment.location != nil ? mapFileName : nil
        )
    }

    // MARK: - 案内マップ(location 指定ミッションのみ)

    /// ミッションが変わった / 60 秒経過 / 50m 以上移動 のいずれかで作り直す
    private func renderMapIfNeeded(
        mission: Mission,
        total: Int,
        achievedCount: Int,
        distanceMeters: Double?,
        bpm: Double?,
        currentLocation: CLLocation?
    ) {
        guard let target = mission.judgment.location else {
            mapFileName = nil
            mapMissionId = nil
            return
        }
        if mapMissionId != mission.id {
            mapFileName = nil
        }
        let movedEnough: Bool = {
            guard let last = mapRenderedLocation else { return true }
            guard let currentLocation else { return false }
            return currentLocation.distance(from: last) >= 50
        }()
        let staleEnough = mapRenderedAt.map { Date().timeIntervalSince($0) >= 60 } ?? true
        let missionChanged = mapMissionId != mission.id
        guard !isRenderingMap, missionChanged || (staleEnough && movedEnough) else { return }

        isRenderingMap = true
        Task {
            defer { isRenderingMap = false }
            guard let image = try? await Self.renderMap(target: target, current: currentLocation),
                  let fileName = try? Self.save(image) else { return }
            mapFileName = fileName
            mapMissionId = mission.id
            mapRenderedAt = Date()
            mapRenderedLocation = currentLocation
            // 生成できたらファイル名込みでもう一度 push
            guard let activity = self.activity else { return }
            let state = contentState(
                mission: mission, total: total, achievedCount: achievedCount,
                distanceMeters: distanceMeters, bpm: bpm
            )
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private static let mapSize = CGSize(width: 220, height: 180)

    /// 目的地中心のスナップショットに、目的地ピン(ティール)と現在地ドットを描く
    private static func renderMap(target: GeoTarget, current: CLLocation?) async throws -> UIImage {
        let targetCoordinate = CLLocationCoordinate2D(latitude: target.latitude, longitude: target.longitude)
        // 現在地が近ければ両方入る範囲、遠ければ目的地周辺だけ
        var span: CLLocationDistance = 600
        if let current {
            let distance = current.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
            span = min(max(distance * 2.4, 500), 4000)
        }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: targetCoordinate,
                                            latitudinalMeters: span, longitudinalMeters: span)
        options.size = mapSize
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size,
                                               format: snapshot.image.imageRendererFormat)
        let accent = UIColor(red: 0.165, green: 0.49, blue: 0.424, alpha: 1) // #2A7D6C
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext

            // 現在地(青ドット)
            if let current {
                let p = snapshot.point(for: current.coordinate)
                if p.x >= 0, p.y >= 0, p.x <= mapSize.width, p.y <= mapSize.height {
                    let dot = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
                    cg.setFillColor(UIColor.white.cgColor)
                    cg.fillEllipse(in: dot)
                    cg.setFillColor(UIColor.systemBlue.cgColor)
                    cg.fillEllipse(in: dot.insetBy(dx: 2.5, dy: 2.5))
                }
            }

            // 目的地ピン(ティールの丸)
            let p = snapshot.point(for: targetCoordinate)
            let pin = CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: pin)
            cg.setFillColor(accent.cgColor)
            cg.fillEllipse(in: pin.insetBy(dx: 3, dy: 3))
        }
    }

    /// App Group に書き出して古いミッションマップを消す(Widget は新しい名前だけ読む)
    private static func save(_ image: UIImage) throws -> String {
        guard let dir = MapSnapshotStore.directoryURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "mission-map-\(UUID().uuidString).png"
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: dir.appending(path: fileName), options: .atomic)

        // 自分が書いた古いミッションマップを掃除
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("mission-map-") && file.lastPathComponent != fileName {
                try? FileManager.default.removeItem(at: file)
            }
        }
        return fileName
    }
}
