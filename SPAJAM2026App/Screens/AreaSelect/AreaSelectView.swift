//
//  AreaSelectView.swift
//  SPAJAM2026App
//
//  01 エリア選択。3 ステップがスライドで切り替わる:
//  Step1 どこへ(マップにピン) → Step2 だれと(−/+で1〜5人) → Step3 温度感(ゆったり/アクティブ/マニア)
//  中央のイラストはステップと選択に応じて変わる(手書きイラスト素材に差し替え予定)。
//  スワイプで前のステップに戻れる。
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

    var body: some View {
        VStack(spacing: 20) {
            stepIndicator
                .padding(.top, 12)
                .padding(.horizontal, 24)

            // スワイプで前後のステップに移動できるページャー
            TabView(selection: $step) {
                slideWhere
                    .padding(.horizontal, 24)
                    .tag(1)
                slideWho
                    .padding(.horizontal, 24)
                    .tag(2)
                slideMood
                    .padding(.horizontal, 24)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .padding(.vertical, 24)
        .background(Color.appBackground)
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
                .background(step >= n ? Color.appAccent : Color(.systemGray5), in: Circle())
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
                            .tint(Color.appAccent)
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
        }
    }

    // MARK: - Step2 だれと(イラストが人数で変わる)

    private var slideWho: some View {
        VStack(spacing: 16) {
            title("だれと行く?", sub: "いっしょに旅する人数を選んでください")

            Spacer()
            illustration(symbol: partySymbol, caption: partySize == 1 ? "ひとり旅" : "\(partySize)人旅")
            Spacer()

            partyStepper

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
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
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

    /// −/+ で 1〜5 人を選ぶステッパー(Figma 人数選択のデザイン準拠)
    private var partyStepper: some View {
        HStack(spacing: 28) {
            stepperButton("minus", disabled: partySize <= 1) { partySize -= 1 }
            Text("\(partySize)人")
                .font(.handTitle)
                .foregroundStyle(Color.inkMain)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.default, value: partySize)
            stepperButton("plus", disabled: partySize >= 5) { partySize += 1 }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func stepperButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(disabled ? Color(.systemGray4) : Color.appAccent, in: Circle())
        }
        .disabled(disabled)
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

    /// 中央イラスト。見ざるキャラ(広瀬さんの差し替え素材が来たらステップごとに切り替える)
    private func illustration(symbol: String, caption: String) -> some View {
        VStack(spacing: 14) {
            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(width: 210, height: 210)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
            Text(caption)
                .font(.handHeadline)
                .foregroundStyle(Color.appAccent)
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
                .background(selected ? Color.appAccent : .white, in: Capsule())
                .foregroundStyle(selected ? .white : Color.inkSub)
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: selected ? 0 : 1))
        }
    }

    private func nextButton(_ label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        BrushButton(label: label, loading: loading, disabled: disabled, action: action)
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
            } catch PlanGenerator.GenError.timeout {
                NSLog("[PlanGen] timed out")
                errorMessage = "生成がタイムアウトしました。電波の良い場所でもう一度お試しください"
            } catch PlanGenerator.GenError.noKey {
                errorMessage = "API キー(Secrets.plist)が設定されていません"
            } catch {
                NSLog("[PlanGen] failed: \(error)")
                errorMessage = "生成に失敗しました。もう一度お試しください"
            }
            isGenerating = false
        }
    }
}
