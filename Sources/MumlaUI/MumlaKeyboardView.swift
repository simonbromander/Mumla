import MumlaCore
import SwiftUI

public struct MumlaKeyboardView: View {
    public var snapshot: KeyboardSessionSnapshot
    public var fullAccess: Bool
    public var pending: Bool
    public var pendingAction: KeyboardSessionCommand.Action?
    public var preview: String?
    public var notice: String?
    public var samples: [Double]
    public var nextKeyboard: AnyView
    public var onRecord: () -> Void
    public var onCancel: () -> Void
    public var onInsert: () -> Void
    public var onEnd: () -> Void
    public var onKey: (String) -> Void
    public var onDelete: () -> Void
    public var onReturn: () -> Void
    public var returnTitle: String
    public var suggestions: [KeyboardTypingSuggestion]
    public var automaticUppercase: Bool
    public var typingRevision: Int
    public var typingLanguage: String
    public var correctionEnabled: Bool
    public var correctionAvailable: Bool
    public var onSuggestion: (KeyboardTypingSuggestion) -> Void
    public var onTypingLanguage: () -> Void
    public var onCorrection: () -> Void
    public var onCursorMove: (Int) -> Void
    @State private var layout = MumlaKeyboardLayout.letters
    @State private var shift = MumlaKeyboardShift()
    @State private var deleteTask: Task<Void, Never>?
    @State private var showActivationRequirement = false
    @State private var accentKey: String?
    @State private var cursorDrag = KeyboardCursorDrag()
    @State private var movingCursor = false
    @State private var suppressSpace = false
    private var active: Bool { snapshot.isAlive() }
    private var recording: Bool { active && snapshot.phase == .recording }

    public init(snapshot: KeyboardSessionSnapshot, fullAccess: Bool, pending: Bool = false, preview: String? = nil,
                notice: String? = nil, samples: [Double] = [], nextKeyboard: AnyView,
                returnTitle: String = "↵", onRecord: @escaping () -> Void, onCancel: @escaping () -> Void,
                onInsert: @escaping () -> Void, onEnd: @escaping () -> Void,
                onKey: @escaping (String) -> Void, onDelete: @escaping () -> Void, onReturn: @escaping () -> Void,
                suggestions: [KeyboardTypingSuggestion] = [], automaticUppercase: Bool = false,
                typingRevision: Int = 0, typingLanguage: String = "sv", correctionEnabled: Bool = true, correctionAvailable: Bool = true,
                onSuggestion: @escaping (KeyboardTypingSuggestion) -> Void = { _ in },
                onTypingLanguage: @escaping () -> Void = {}, onCorrection: @escaping () -> Void = {},
                onCursorMove: @escaping (Int) -> Void = { _ in },
                pendingAction: KeyboardSessionCommand.Action? = nil) {
        self.snapshot = snapshot; self.fullAccess = fullAccess; self.pending = pending
        self.pendingAction = pendingAction
        self.preview = preview; self.notice = notice; self.samples = samples; self.nextKeyboard = nextKeyboard
        self.returnTitle = returnTitle; self.onRecord = onRecord; self.onCancel = onCancel
        self.onInsert = onInsert; self.onEnd = onEnd; self.onKey = onKey; self.onDelete = onDelete; self.onReturn = onReturn
        self.suggestions = suggestions; self.automaticUppercase = automaticUppercase; self.typingRevision = typingRevision
        self.typingLanguage = typingLanguage; self.correctionEnabled = correctionEnabled
        self.correctionAvailable = correctionAvailable
        self.onSuggestion = onSuggestion; self.onTypingLanguage = onTypingLanguage; self.onCorrection = onCorrection
        self.onCursorMove = onCursorMove
    }

    public var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 320
            let gap: CGFloat = geometry.size.width < 350 ? 3 : 5
            VStack(spacing: compact ? 5 : 8) {
                HStack(spacing: 8) {
                    lcd(compact: compact)
                    Button {
                        if !fullAccess || !active { showActivationRequirement = true }
                        else { onRecord() }
                    } label: {
                        Group {
                            if pending { Image(systemName: "ellipsis") }
                            else if recording { Image(systemName: "stop.fill") }
                            else if snapshot.phase == .failed && snapshot.canRetry { Image(systemName: "arrow.clockwise") }
                            else { Image(systemName: "mic.fill") }
                        }.font(.system(size: compact ? 17 : 21, weight: .medium))
                            .padding(.top, compact ? 8 : 6)
                            .foregroundStyle(recording ? MumlaStyle.recording : MumlaStyle.accent)
                            .transaction { $0.animation = nil }
                    }
                    .buttonStyle(MumlaStereoKeyStyle(isLatched: recording, height: compact ? 48 : 60) { pressed in
                        if pressed { MumlaFeedback.press() }
                    })
                    .frame(width: compact ? 48 : 54)
                    .disabled(fullAccess && active && (pending || ![.ready, .recording, .failed].contains(snapshot.phase)))
                    .accessibilityLabel(!fullAccess || !active ? mText("Aktivera diktering", "Enable dictation") : recording ? mText("Stoppa diktering", "Stop dictation") : snapshot.phase == .failed && snapshot.canRetry ? mText("Försök igen", "Retry dictation") : mText("Spela in diktering", "Record dictation"))
                    .accessibilityIdentifier("keyboard.record")
                    if recording {
                        tool("xmark", label: mText("Avbryt diktering", "Cancel dictation"), action: onCancel)
                            .disabled(pending).accessibilityIdentifier("keyboard.cancel")
                    } else if active {
                        tool("power", label: mText("Avsluta session", "End session"), action: onEnd)
                            .disabled(pending).accessibilityIdentifier("keyboard.end")
                    }
                }
                if showActivationRequirement {
                    activationRequirement(compact: compact)
                } else {
                    suggestionStrip(compact: compact)
                    if let preview, !preview.isEmpty {
                        HStack(spacing: 8) {
                            Text(preview).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            tool("arrow.down.to.line", label: mText("Infoga transkript", "Insert transcript"), action: onInsert)
                                .disabled(pending)
                                .accessibilityIdentifier("keyboard.insert")
                            tool("xmark", label: mText("Behåll i historiken", "Keep in history"), action: onCancel)
                                .disabled(pending).accessibilityIdentifier("keyboard.keep")
                        }.frame(height: 36)
                    }
                    ForEach(Array(layout.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: gap) {
                            if index == 2 {
                                Button {
                                    accentKey = nil
                                    if layout == .letters { shift.tap(at: Date().timeIntervalSinceReferenceDate) }
                                    else { layout = layout == .numbers ? .symbols : .numbers }
                                } label: {
                                    Group {
                                        if layout == .letters { Image(systemName: shift.locked ? "capslock.fill" : shift.uppercase ? "shift.fill" : "shift") }
                                        else { Text(layout == .numbers ? "#+=" : "123") }
                                    }.font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .frame(width: geometry.size.width < 350 ? 38 : 44, height: compact ? 34 : 42)
                                }.buttonStyle(MumlaKeyStyle(radius: 5))
                                    .accessibilityLabel(layout == .letters ? mText("Skift", "Shift") : mText("Fler symboler", "More symbols"))
                                    .accessibilityValue(shift.locked ? mText("Skiftlås", "Caps lock") : shift.uppercase ? mText("På", "On") : mText("Av", "Off"))
                                    .accessibilityIdentifier("keyboard.shift")
                            }
                            ForEach(row, id: \.self) { key in
                                let output = layout == .letters && shift.uppercase ? key.uppercased() : key
                                Button {
                                    if accentKey == output { return }
                                    accentKey = nil
                                    shift.didType(); onKey(output)
                                } label: {
                                    Text(output).font(.system(size: 17, weight: .medium, design: .monospaced))
                                        .frame(maxWidth: .infinity).frame(height: compact ? 34 : 42)
                                }.buttonStyle(MumlaKeyStyle(radius: 5))
                                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                                        guard !KeyboardAccents.alternatives(for: output).isEmpty else { return }
                                        accentKey = output; MumlaFeedback.press()
                                    })
                                    .accessibilityAction(named: mText("Accenter", "Accents")) {
                                        if !KeyboardAccents.alternatives(for: output).isEmpty { accentKey = output }
                                    }
                                    .accessibilityIdentifier("keyboard.key.\(key)")
                            }
                            if index == 2 { deleteKey(compact: compact, width: geometry.size.width < 350 ? 38 : 44) }
                        }
                    }
                    HStack(spacing: gap) {
                        Button {
                            layout = layout == .letters ? .numbers : .letters
                            accentKey = nil; shift.reset(); shift.updateAutomatic(automaticUppercase)
                        } label: {
                            Text(layout == .letters ? "123" : "ABC").font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 42, height: compact ? 34 : 42)
                        }.buttonStyle(MumlaKeyStyle(radius: 5)).accessibilityIdentifier("keyboard.layout")
                        nextKeyboard.frame(width: 38, height: compact ? 34 : 42).mumlaSurface(radius: 5)
                        Button {
                            guard !suppressSpace else { return }
                            accentKey = nil; onKey(" ")
                        } label: {
                            Group {
                                if movingCursor { Image(systemName: "arrow.left.and.right") }
                                else { Text("mumla") }
                            }.font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(MumlaStyle.secondary).frame(maxWidth: .infinity).frame(height: compact ? 34 : 42)
                        }.buttonStyle(MumlaKeyStyle(radius: 5))
                            .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    if case .second(true, let drag) = value {
                                        if !movingCursor { movingCursor = true; suppressSpace = true; cursorDrag.reset(); MumlaFeedback.press() }
                                        if let drag {
                                            let offset = cursorDrag.move(translation: drag.translation.width)
                                            if offset != 0 { onCursorMove(offset) }
                                        }
                                    }
                                }.onEnded { _ in
                                    movingCursor = false; cursorDrag.reset()
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(100))
                                        suppressSpace = false
                                    }
                                })
                            .accessibilityLabel(mText("Mellanslag", "Space"))
                            .accessibilityAction(named: mText("Flytta markören åt vänster", "Move cursor left")) { onCursorMove(-1) }
                            .accessibilityAction(named: mText("Flytta markören åt höger", "Move cursor right")) { onCursorMove(1) }
                            .accessibilityIdentifier("keyboard.space")
                        Button { accentKey = nil; onKey(".") } label: {
                            Text(".").font(.system(size: 18, design: .monospaced)).frame(width: 30, height: compact ? 34 : 42)
                        }.buttonStyle(MumlaKeyStyle(radius: 5)).accessibilityLabel(mText("Punkt", "Period"))
                        Button { accentKey = nil; onReturn() } label: {
                            Text(returnTitle).font(.system(size: 13, weight: .medium, design: .monospaced))
                                .lineLimit(1).minimumScaleFactor(0.7).frame(width: 54, height: compact ? 34 : 42)
                        }.buttonStyle(MumlaKeyStyle(radius: 5)).accessibilityLabel(returnTitle == "↵" ? mText("Retur", "Return") : returnTitle)
                            .accessibilityIdentifier("keyboard.return")
                    }
                }
            }
            .padding(.horizontal, 6).padding(.vertical, compact ? 6 : 9)
            .frame(maxWidth: 680).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(MumlaStyle.panel).foregroundStyle(MumlaStyle.ink)
        .preferredColorScheme(MumlaAppearance(rawValue: snapshot.appearance)?.colorScheme)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear { shift.updateAutomatic(automaticUppercase) }
        .onChange(of: typingRevision) { _, _ in shift.updateAutomatic(automaticUppercase) }
        .onChange(of: automaticUppercase) { _, uppercase in shift.updateAutomatic(uppercase) }
        .onChange(of: fullAccess && active) { _, ready in if ready { showActivationRequirement = false } }
        .onChange(of: recording) { _, active in if active { MumlaFeedback.recordStart() } else { MumlaFeedback.recordStop() } }
        .onDisappear {
            deleteTask?.cancel(); deleteTask = nil; showActivationRequirement = false
            accentKey = nil; movingCursor = false; suppressSpace = false; cursorDrag.reset()
        }
    }

    private func suggestionStrip(compact: Bool) -> some View {
        HStack(spacing: 4) {
            if let accentKey {
                ForEach(KeyboardAccents.alternatives(for: accentKey), id: \.self) { accent in
                    Button {
                        self.accentKey = nil; shift.didType(); onKey(accent); MumlaFeedback.press()
                    } label: {
                        Text(accent).font(.system(size: 17, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity).frame(height: compact ? 26 : 30)
                    }.buttonStyle(MumlaKeyStyle(radius: 4)).accessibilityIdentifier("keyboard.accent.\(accent.lowercased())")
                }
                Button { self.accentKey = nil } label: {
                    Image(systemName: "xmark").frame(width: 30, height: compact ? 26 : 30)
                }.buttonStyle(MumlaKeyStyle(radius: 4)).accessibilityLabel(mText("Stäng accenter", "Close accents"))
                    .accessibilityIdentifier("keyboard.accentClose")
            } else {
                Button(action: onTypingLanguage) {
                    Text(typingLanguage.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MumlaStyle.accent).frame(width: 30, height: compact ? 26 : 30)
                }.buttonStyle(MumlaKeyStyle(radius: 4))
                    .accessibilityLabel(mText("Skrivspråk", "Typing language"))
                    .accessibilityValue(typingLanguage == "sv" ? "Svenska" : "English")
                    .accessibilityIdentifier("keyboard.language")
                ForEach(0..<3) { index in
                    if index < suggestions.count {
                        let suggestion = suggestions[index]
                        Button { shift.didType(); onSuggestion(suggestion) } label: {
                            Text(suggestion.text).font(.system(size: 12, weight: suggestion.original ? .regular : .medium, design: .monospaced))
                                .lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: .infinity).frame(height: compact ? 26 : 30)
                        }.buttonStyle(MumlaKeyStyle(radius: 4))
                            .accessibilityLabel(suggestion.original ? mText("Behåll \(suggestion.text)", "Keep \(suggestion.text)") : suggestion.text)
                            .accessibilityIdentifier("keyboard.suggestion.\(index)")
                    } else { Color.clear.frame(maxWidth: .infinity).frame(height: compact ? 26 : 30) }
                }
                Button(action: onCorrection) {
                    Image(systemName: correctionEnabled && correctionAvailable ? "text.badge.checkmark" : "text.badge.xmark")
                        .font(.system(size: 13)).foregroundStyle(correctionEnabled && correctionAvailable ? MumlaStyle.accent : MumlaStyle.secondary)
                        .frame(width: 30, height: compact ? 26 : 30)
                }.buttonStyle(MumlaKeyStyle(radius: 4)).disabled(!correctionAvailable)
                    .accessibilityLabel(mText("Autokorrigering", "Autocorrect"))
                    .accessibilityValue(correctionEnabled && correctionAvailable ? mText("På", "On") : mText("Av", "Off"))
                    .accessibilityIdentifier("keyboard.autocorrect")
            }
        }.padding(3).mumlaRecess(radius: 6).frame(height: compact ? 32 : 36)
    }

    private func activationRequirement(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(!fullAccess
                ? mText("Aktivera Full åtkomst för Mumla under Inställningar → Allmänt → Tangentbord → Tangentbord.", "Enable Full Access for Mumla in Settings → General → Keyboard → Keyboards.")
                : [notice ?? snapshot.error,
                   mText("Öppna Mumla, tryck på tangentbordsikonen och välj Starta session. Eller använd Mumlas widget eller genväg. Gå sedan tillbaka hit.", "Open Mumla, tap the keyboard icon and choose Start session. Or use Mumla's widget or shortcut. Then return here.")]
                    .compactMap { $0 }.joined(separator: "\n\n"))
                .font(.system(size: compact ? 11 : 13, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("keyboard.activationMessage")
            Spacer(minLength: 0)
            HStack {
                nextKeyboard.frame(width: 38, height: 36).mumlaSurface(radius: 5)
                Spacer()
                tool("xmark", label: mText("Stäng", "Close")) { showActivationRequirement = false }
                    .accessibilityIdentifier("keyboard.activationClose")
            }
        }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .mumlaRecess(radius: 7)
    }

    private func lcd(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                MumlaRecordingLight(recording: recording)
                Text(status).font(.system(size: 11, weight: .semibold, design: .monospaced)).lineLimit(1)
                Spacer(minLength: 0)
                if recording, let started = snapshot.recordingStartedAt {
                    Text(started, style: .timer).monospacedDigit().font(.system(size: 13, design: .monospaced))
                        .multilineTextAlignment(.trailing).frame(width: 50)
                } else { Text("SV / 01").font(.system(size: 9, design: .monospaced)) }
            }
            if recording && !pending { MumlaWaveform(samples: samples, active: true).frame(height: compact ? 12 : 20) }
            else {
                Text(notice ?? detail).font(.system(size: 10, design: .monospaced)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(MumlaStyle.lcdInk).padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: compact ? 48 : 60, maxHeight: compact ? 48 : 60, alignment: .leading)
        .background(MumlaStyle.lcd).clipShape(RoundedRectangle(cornerRadius: 5))
        .padding(3).mumlaRecess(radius: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status).accessibilityValue(notice ?? detail)
        .accessibilityIdentifier("keyboard.status")
    }
    private var status: String {
        if !fullAccess { return mText("FULL ÅTKOMST", "FULL ACCESS") }
        if !active && snapshot.sessionID != nil && snapshot.phase != .inactive {
            return snapshot.expiresAt <= Date() ? mText("SESSIONEN ÄR SLUT", "SESSION EXPIRED") : mText("ANSLUTNING BRUTEN", "CONNECTION LOST")
        }
        if !active { return mText("INGEN SESSION", "NO SESSION") }
        if pending, let pendingAction {
            switch pendingAction {
            case .start: return mText("STARTAR MIKROFON", "ARMING MICROPHONE")
            case .stop: return mText("AVSLUTAR KLIPP", "FINISHING CLIP")
            case .cancel: return mText("AVBRYTER", "CANCELLING")
            case .retry: return mText("BEARBETAR", "PROCESSING")
            case .consume: return mText("INFOGAR", "INSERTING")
            case .end: return mText("AVSLUTAR SESSION", "ENDING SESSION")
            }
        }
        switch snapshot.phase {
        case .recording: return "REC"
        case .transcribing: return mText("BEARBETAR", "PROCESSING")
        case .result: return mText("TEXTEN ÄR KLAR", "TEXT READY")
        case .failed: return mText("FÖRSÖK IGEN", "TRY AGAIN")
        case .preparing: return mText("FÖRBEREDER", "PREPARING")
        case .ready, .inactive: return "STANDBY"
        }
    }
    private var detail: String {
        if !fullAccess { return mText("Aktivera Full åtkomst i Inställningar.", "Enable Full Access in Settings.") }
        if !active { return mText("Starta tangentbordssessionen i Mumla.", "Start the keyboard session in Mumla.") }
        if pendingAction == .start { return mText("Börja prata när REC visas.", "Speak when REC appears.") }
        if pending { return mText("Väntar på Mumla.", "Waiting for Mumla.") }
        if snapshot.phase == .failed {
            return snapshot.canRetry ? mText("Klippet finns kvar i Mumla.", "Your clip is saved in Mumla.") : mText("Öppna Mumla eller spela in igen.", "Open Mumla or record again.")
        }
        if snapshot.phase == .transcribing { return mText("Skriver dina ord på enheten.", "Transcribing on this device.") }
        if snapshot.phase == .result { return mText("Sparat i historiken.", "Saved in history.") }
        return mText("Redo att lyssna.", "Ready to listen.")
    }
    private func tool(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 16)).frame(width: 36, height: 36) }
            .buttonStyle(MumlaKeyStyle(radius: 5)).accessibilityLabel(label)
    }
    private func deleteKey(compact: Bool, width: CGFloat) -> some View {
        Button { accentKey = nil; onDelete() } label: {
            Image(systemName: "delete.left").font(.system(size: 18)).frame(width: width, height: compact ? 34 : 42)
        }
        .buttonStyle(MumlaKeyStyle(radius: 5))
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in
            deleteTask?.cancel()
            deleteTask = Task { @MainActor in
                while !Task.isCancelled { onDelete(); do { try await Task.sleep(for: .milliseconds(85)) } catch { return } }
            }
        })
        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in deleteTask?.cancel(); deleteTask = nil })
        .accessibilityLabel(mText("Radera", "Delete")).accessibilityIdentifier("keyboard.delete")
    }
}
