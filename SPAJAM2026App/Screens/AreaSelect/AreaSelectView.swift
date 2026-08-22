//
//  AreaSelectView.swift
//  SPAJAM2026App
//
//  01 エリア選択。3 ステップがスライドで切り替わる:
//  Step1 どこへ(マップにピン) → Step2 だれと(1〜5人) → Step3 温度感(ゆったり/アクティブ/マニア)
//  中央のイラストはステップと選択に応じて変わる(手書きイラスト素材に差し替え予定)。
//  ボタンは「つぎへ」のみ(戻るなし)。
//  複数人: Step2 で 2 人以上を選ぶとルームを作って招待コードを表示し、子が揃うまで「つぎへ」を無効にする。
//  ヘッダ右のアカウントアイコン → 「招待コードを入力」で子として参加できる。
//

import CoreLocation
import MapKit
import SwiftUI

struct AreaSelectView: View {
    /// プランができた(親 or ひとり旅)。複数人なら親の RoomMembership を渡す
    var onPlanReady: (TravelPlan, RoomMembership?) -> Void
    /// 招待コードで子として参加した
    var onJoinedRoom: (RoomMembership) -> Void

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671), // 東京駅
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @State private var step = 1
    @State private var pin: CLLocationCoordinate2D?
    @State private var partySize = 2
    @State private var mood: TripMood = .relaxed
    @State private var isGenerating = false
    @State private var errorMessage: String?

    // 複数人(親)
    @State private var roomCode: String?
    @State private var isCreatingRoom = false
    @State private var roomError: String?
    @State private var observer = TripRoomObserver()

    // 招待コード入力(子)
    @State private var isJoinDialogPresented = false

    private let slide: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    var body: some View {
        VStack(spacing: 20) {
            stepIndicator
                .padding(.top, 12)

            ZStack {
                switch step {
                case 1: slideWhere.transition(slide)
                case 2: slideWho.transition(slide)
                default: slideMood.transition(slide)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .padding(24)
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
        .onChange(of: partySize) { _, newValue in
            syncRoom(partySize: newValue)
        }
        .sheet(isPresented: $isJoinDialogPresented) {
            InviteCodeJoinView { name, code in
                do {
                    let membership = try await TripRoomService.shared.join(code: code, name: name)
                    onJoinedRoom(membership)
                    return nil
                } catch {
                    NSLog("[Room] join failed: \(error)")
                    return error.localizedDescription
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - ステップインジケータ

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            stepChip(1, "どこへ")
            stepChip(2, "だれと")
            stepChip(3, "温度感")
            Spacer()
            accountMenu
        }
    }

    /// ヘッダ右のアカウントアイコン。招待コードで参加する入口
    private var accountMenu: some View {
        Menu {
            Button {
                isJoinDialogPresented = true
            } label: {
                Label("招待コードを入力", systemImage: "ticket")
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkSub)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
        }
    }

    private func stepChip(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(n)")
                .font(.handCaption2)
                .foregroundStyle(step >= n ? .white : .secondary)
                .frame(width: 18, height: 18)
                .background(step >= n ? Color.orange : Color(.systemGray5), in: Circle())
            Text(label)
                .font(.handCaption)
                .foregroundStyle(step == n ? Color.inkMain : Color.inkSub)
        }
    }

    // MARK: - Step1 どこへ(マップが主役)

    private var slideWhere: some View {
        VStack(spacing: 16) {
            title("どこへ行く?", sub: "マップにピンを置くと、周辺の主要スポットから旅をつくります")

            MapReader { proxy in
                Map(position: $camera) {
                    if let pin {
                        Marker("旅先", coordinate: pin)
                            .tint(.orange)
                    }
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        pin = coordinate
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))

            nextButton("つぎへ", disabled: pin == nil) { step = 2 }

            Button {
                onPlanReady(.bundledDemoPlan(), nil)
            } label: {
                Text("デモプラン(浅草)で始める")
                    .font(.handBody)
                    .foregroundStyle(Color.inkSub)
            }
        }
    }

    // MARK: - Step2 だれと(イラストが人数で変わる)

    private var slideWho: some View {
        VStack(spacing: 16) {
            title("だれと行く?", sub: "いっしょに旅する人数を選んでください")

            Spacer()
            illustration(symbol: partySymbol, caption: partySize == 1 ? "ひとり旅" : "\(partySize)人旅")
            Spacer()

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    selectChip("\(n)", selected: partySize == n) { partySize = n }
                }
            }

            if partySize >= 2 {
                inviteCard
            }

            nextButton("つぎへ", disabled: !canLeaveWhoStep) { step = 3 }
        }
        .onAppear { syncRoom(partySize: partySize) }
    }

    /// 2 人以上なら子が揃うまで進めない(Firebase 未構成時はデモ用にそのまま進める)
    private var canLeaveWhoStep: Bool {
        guard partySize >= 2, FirebaseBootstrap.isConfigured else { return true }
        return roomCode != nil && observer.isPartyComplete
    }

    /// 招待コードと参加状況
    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("招待コード")
                    .font(.handCaption)
                    .foregroundStyle(Color.inkSub)
                Spacer()
                if let roomCode {
                    Button {
                        UIPasteboard.general.string = roomCode
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.handCaption)
                    }
                    .tint(.orange)
                }
            }
            if let roomCode {
                Text(roomCode)
                    .font(.handNumber(34))
                    .kerning(6)
                    .foregroundStyle(Color.inkMain)
                    .frame(maxWidth: .infinity)
            } else if isCreatingRoom {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let roomError {
                Text(roomError)
                    .font(.handCaption)
                    .foregroundStyle(.red)
            }

            let guestCapacity = partySize - 1
            let names = observer.members.map(\.name)
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.orange)
                if names.isEmpty {
                    Text("参加を待っています(あと \(guestCapacity) 人)")
                } else {
                    Text(names.joined(separator: "、") + (observer.isPartyComplete ? " が参加(そろいました)" : " が参加(あと \(max(0, guestCapacity - names.count)) 人)"))
                }
            }
            .font(.handCaption)
            .foregroundStyle(Color.inkSub)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    /// 人数に応じてルームを作成/更新する。1 人なら何もしない(作成済みルームは残す)
    private func syncRoom(partySize: Int) {
        guard partySize >= 2, FirebaseBootstrap.isConfigured else { return }
        if let roomCode {
            Task { try? await TripRoomService.shared.updatePartySize(code: roomCode, partySize: partySize) }
            return
        }
        guard !isCreatingRoom else { return }
        isCreatingRoom = true
        roomError = nil
        Task {
            do {
                let code = try await TripRoomService.shared.createRoom(partySize: self.partySize)
                roomCode = code
                observer.start(code: code)
            } catch {
                NSLog("[Room] create failed: \(error)")
                roomError = "招待コードを発行できませんでした。通信環境を確認してください"
            }
            isCreatingRoom = false
        }
    }

    private var partySymbol: String {
        switch partySize {
        case 1: "figure.walk"
        case 2: "figure.2"
        default: "figure.2.and.child.holdinghands"
        }
    }

    // MARK: - Step3 温度感(イラストが温度感で変わる)

    private var slideMood: some View {
        VStack(spacing: 16) {
            title("旅の温度感は?", sub: "ミッションの難易度とテイストが変わります")

            Spacer()
            illustration(symbol: moodSymbol, caption: mood.rawValue)
            Spacer()

            HStack(spacing: 8) {
                ForEach(TripMood.allCases) { m in
                    selectChip(m.rawValue, selected: mood == m) { mood = m }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.handCaption)
                    .foregroundStyle(.red)
            }

            nextButton(isGenerating ? "プランを生成中…" : "この旅先でプランをつくる", loading: isGenerating, disabled: isGenerating) {
                generate()
            }
        }
    }

    private var moodSymbol: String {
        switch mood {
        case .relaxed: "cup.and.saucer.fill"
        case .active: "figure.run"
        case .mania: "binoculars.fill"
        }
    }

    // MARK: - 部品

    /// 中央イラスト。広瀬さんの手書きイラスト素材に差し替える前提のプレースホルダ
    private func illustration(symbol: String, caption: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 200, height: 200)
                Image(systemName: symbol)
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
            }
            .contentTransition(.symbolEffect(.replace))
            Text(caption)
                .font(.handHeadline)
                .foregroundStyle(Color.inkSub)
        }
        .animation(.default, value: symbol)
    }

    private func title(_ main: String, sub: String) -> some View {
        ScreenHeader(main, subtitle: sub)
    }

    private func selectChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.handBody)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.orange : .white, in: Capsule())
                .foregroundStyle(selected ? .white : Color.inkSub)
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: selected ? 0 : 1))
        }
    }

    private func nextButton(_ label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white) }
                Text(label)
            }
            .font(.handHeadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(disabled)
    }

    private func generate() {
        guard let pin else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let plan = try await PlanGenerator().generate(at: pin, partySize: partySize, mood: mood)
                let membership = (partySize >= 2 ? roomCode : nil).map { RoomMembership(code: $0, role: .host, name: nil) }
                onPlanReady(plan, membership)
            } catch {
                NSLog("[PlanGen] failed: \(error)")
                errorMessage = "生成に失敗しました。もう一度試すか、デモプランで始めてください"
            }
            isGenerating = false
        }
    }
}
