import MumlaCore
import MumlaUI
import SwiftUI
import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let client = KeyboardClient()
    let typing = KeyboardTypingAssistant()
    private var host: UIHostingController<KeyboardRoot>?
    private var heightConstraint: NSLayoutConstraint?
    private var visible = false
    private var applyingEdit = false
    private var lastContext: KeyboardTypingContext?
    private var documentID: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        primaryLanguage = typing.language
        Task { [weak self] in
            guard let self else { return }
            let lexicon = await requestSupplementaryLexicon()
            typing.setLexicon(lexicon.entries.map { (input: $0.userInput, output: $0.documentText) })
        }
        client.onRefresh = { [weak self] in self?.receiveResult(); self?.updateHeight() }
        let root = KeyboardRoot(client: client, controller: self)
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 344)
        height.priority = .init(999); height.isActive = true
        heightConstraint = height; self.host = host
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); visible = true
        client.returnTitle = returnTitle
        refreshTyping(external: true)
        client.start(fullAccess: hasFullAccess); updateHeight()
    }
    override func viewWillDisappear(_ animated: Bool) {
        visible = false; client.pause(); typing.deactivate(); lastContext = nil
        super.viewWillDisappear(animated)
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); updateHeight() }
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        client.fullAccess = hasFullAccess
        client.returnTitle = returnTitle
        if !applyingEdit { refreshTyping(external: true) }
        receiveResult()
    }
    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        if !applyingEdit { refreshTyping(external: true) }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning(); client.samples = []; client.result = nil
        typing.deactivate(); lastContext = nil
    }

    func record() {
        if client.snapshot.phase == .recording { client.send(.stop) }
        else if client.snapshot.phase == .failed && client.snapshot.canRetry { client.send(.retry) }
        else { client.send(.start, documentID: textDocumentProxy.documentIdentifier) }
    }
    func insertResult() {
        guard visible, hasFullAccess, let store = client.store, let result = client.result,
              client.snapshot.isAlive(), result.id == client.snapshot.resultID,
              result.sessionID == client.snapshot.sessionID else { return }
        do {
            let fresh = try store.snapshot()
            guard fresh.isAlive(), fresh.sessionID == result.sessionID, fresh.resultID == result.id else { return }
            if try store.claim(result.id) {
                applyingEdit = true
                textDocumentProxy.insertText(result.text)
                applyingEdit = false
                typing.reset(); refreshTyping()
                MumlaFeedback.success()
            }
            client.send(.consume, resultID: result.id)
            client.result = nil
        } catch { client.notice = mText("Öppna Mumla. Texten finns i historiken.", "Open Mumla. Your text is in history.") }
    }
    private func receiveResult() {
        guard let result = client.result else { return }
        if client.store?.hasClaim(result.id) == true { client.send(.consume, resultID: result.id); return }
        if result.shouldAutoInsert(snapshot: client.snapshot, requestID: client.requestID,
                                   documentID: textDocumentProxy.documentIdentifier, visible: visible) { insertResult() }
    }
    private func updateHeight() {
        let landscape = view.window?.windowScene?.interfaceOrientation.isLandscape == true
        let height: CGFloat = landscape ? (client.result == nil ? 266 : 306) : (client.result == nil ? 344 : 384)
        if heightConstraint?.constant != height { heightConstraint?.constant = height }
    }
    func type(_ text: String) {
        refreshTyping()
        apply(typing.insert(text))
    }
    func delete() {
        refreshTyping()
        apply(typing.delete())
    }
    func choose(_ suggestion: KeyboardTypingSuggestion) {
        refreshTyping()
        if let edit = typing.choose(suggestion) { apply(edit) }
    }
    func moveCursor(_ offset: Int) {
        guard textDocumentProxy.selectedText?.isEmpty != false else { return }
        applyingEdit = true
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        applyingEdit = false
        typing.reset(); refreshTyping()
    }
    private func apply(_ edit: KeyboardTextEdit) {
        applyingEdit = true
        for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
        if !edit.insertion.isEmpty { textDocumentProxy.insertText(edit.insertion) }
        applyingEdit = false
        refreshTyping()
    }
    private func refreshTyping(external: Bool = false) {
        let proxy = textDocumentProxy
        // iOS can return nil context for a genuinely empty field.
        let before = proxy.documentContextBeforeInput ?? (proxy.hasText ? nil : "")
        let context = KeyboardTypingContext(before: before,
            after: proxy.documentContextAfterInput, selection: proxy.selectedText)
        let changedDocument = documentID != proxy.documentIdentifier
        if changedDocument { typing.reset() }
        documentID = proxy.documentIdentifier
        let capitalization: KeyboardCapitalization
        switch proxy.autocapitalizationType ?? .sentences {
        case .none: capitalization = .none
        case .words: capitalization = .words
        case .allCharacters: capitalization = .allCharacters
        default: capitalization = .sentences
        }
        let literalField = [.emailAddress, .URL, .numberPad, .decimalPad, .asciiCapableNumberPad, .phonePad, .namePhonePad].contains(proxy.keyboardType ?? .default)
        typing.update(context: context, capitalization: capitalization,
            allowsCorrection: !literalField && proxy.autocorrectionType != .no,
            externalChange: changedDocument || (external && context != lastContext))
        lastContext = context
    }
    private var returnTitle: String {
        switch textDocumentProxy.returnKeyType {
        case .done: mText("Klart", "Done")
        case .go: mText("Gå", "Go")
        case .search: mText("Sök", "Search")
        case .send: mText("Skicka", "Send")
        case .next: mText("Nästa", "Next")
        default: "↵"
        }
    }
}

@MainActor
private struct KeyboardRoot: View {
    @ObservedObject var client: KeyboardClient
    @ObservedObject var typing: KeyboardTypingAssistant
    weak var controller: KeyboardViewController?
    init(client: KeyboardClient, controller: KeyboardViewController) {
        self.client = client; self.typing = controller.typing; self.controller = controller
    }
    var body: some View {
        MumlaKeyboardView(snapshot: client.snapshot, fullAccess: client.fullAccess,
            pending: client.pending != nil, preview: client.result?.text, notice: client.notice,
            samples: client.samples, nextKeyboard: AnyView(KeyboardGlobe(controller: controller)),
            returnTitle: client.returnTitle,
            onRecord: { controller?.record() }, onCancel: {
                if let result = client.result { client.send(.consume, resultID: result.id); client.result = nil }
                else { client.send(.cancel) }
            },
            onInsert: { controller?.insertResult() }, onEnd: { client.send(.end) },
            onKey: { controller?.type($0) }, onDelete: { controller?.delete() },
            onReturn: { controller?.type("\n") },
            suggestions: typing.suggestions, automaticUppercase: typing.automaticUppercase,
            typingRevision: typing.revision, typingLanguage: typing.language,
            correctionEnabled: typing.correctionEnabled, correctionAvailable: typing.allowsCorrection,
            onSuggestion: { controller?.choose($0) }, onTypingLanguage: {
                typing.toggleLanguage(); controller?.primaryLanguage = typing.language
            },
            onCorrection: { typing.toggleCorrection() }, onCursorMove: { controller?.moveCursor($0) },
            pendingAction: client.pending?.action)
    }
}

@MainActor
private struct KeyboardGlobe: UIViewRepresentable {
    weak var controller: KeyboardViewController?
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.accessibilityLabel = mText("Nästa tangentbord", "Next keyboard")
        button.accessibilityIdentifier = "keyboard.globe"
        if let controller {
            button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        }
        return button
    }
    func updateUIView(_ button: UIButton, context: Context) {
        button.tintColor = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    }
}

@MainActor
private final class KeyboardClient: ObservableObject {
    @Published var snapshot = KeyboardSessionSnapshot()
    @Published var fullAccess = false
    @Published var result: KeyboardSessionResult?
    @Published var samples = Array(repeating: 0.0, count: 43)
    @Published var notice: String?
    @Published var pending: KeyboardSessionCommand?
    @Published var returnTitle = "↵"
    var requestID: UUID?
    var store: KeyboardSessionStore?
    var onRefresh: (() -> Void)?
    private var task: Task<Void, Never>?
    private var stateSignal: KeyboardSessionSignal?

    func start(fullAccess: Bool) {
        pause(); self.fullAccess = fullAccess
        store = fullAccess ? KeyboardSessionStore.shared() : nil
        if fullAccess {
            stateSignal = KeyboardSessionSignal(.state) { [weak self] in
                Task { @MainActor [weak self] in self?.refresh() }
            }
        }
        refresh()
        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                self?.refresh()
            }
        }
    }
    func pause() { task?.cancel(); task = nil; stateSignal = nil }
    func send(_ action: KeyboardSessionCommand.Action, documentID: UUID? = nil, resultID: UUID? = nil) {
        // Resolve an acknowledgement before accepting a new tap, even between polling ticks.
        refresh(notifyController: false)
        guard fullAccess, pending == nil, let store, let id = snapshot.sessionID, snapshot.isAlive() else { return }
        let command = KeyboardSessionCommand(sessionID: id, action: action, requestID: snapshot.requestID,
                                             documentID: documentID, resultID: resultID)
        guard snapshot.accepts(command) else { return }
        do {
            try store.send(command); pending = command; notice = nil
            if action == .start { requestID = command.id }
        } catch { notice = mText("Öppna Mumla för att starta om sessionen.", "Open Mumla to restart the session.") }
    }
    private func refresh(notifyController: Bool = true) {
        guard fullAccess else { snapshot = .init(); result = nil; pending = nil; notice = nil; return }
        if store == nil { store = KeyboardSessionStore.shared() }
        guard let store else {
            snapshot = .init(); result = nil; pending = nil
            notice = mText("Delad lagring saknas. Installera om Mumla.", "Shared storage is unavailable. Reinstall Mumla.")
            return
        }
        do {
            let next = try store.snapshot()
            if next.isAlive() {
                if next.sessionID != snapshot.sessionID || !snapshot.isAlive() {
                    requestID = nil; result = nil; pending = nil; notice = nil
                }
                snapshot = next
                if UserDefaults.standard.object(forKey: MumlaFeedback.preferenceKey) as? Bool != next.hapticsEnabled {
                    UserDefaults.standard.set(next.hapticsEnabled, forKey: MumlaFeedback.preferenceKey)
                }
                if let pending, snapshot.acknowledgedCommandID == pending.id { self.pending = nil }
                if snapshot.phase == .recording {
                    if samples.count >= 43 { samples.removeFirst() }
                    samples.append(min(1, max(0, snapshot.inputLevel)))
                }
                if snapshot.phase == .result, result?.id != snapshot.resultID {
                    let packet = try store.result()
                    result = packet?.sessionID == snapshot.sessionID && packet?.id == snapshot.resultID ? packet : nil
                } else if snapshot.phase != .result { result = nil }
            } else {
                snapshot = next; result = nil; samples = Array(repeating: 0, count: 43)
                pending = nil; requestID = nil
                if next.sessionID != nil && next.phase != .inactive {
                    notice = next.expiresAt <= Date()
                        ? mText("Sessionens 15 minuter är slut.", "The 15-minute session expired.")
                        : mText("Mumla-sessionen svarar inte. Starta om den i appen.", "The Mumla session is not responding. Restart it in the app.")
                } else { notice = next.error }
            }
            if let pending, Date().timeIntervalSince(pending.createdAt) >= 5 {
                self.pending = nil; notice = mText("Öppna Mumla för att starta om sessionen.", "Open Mumla to restart the session.")
            }
            if notifyController { onRefresh?() }
        } catch {
            snapshot = .init(); result = nil; pending = nil; requestID = nil
            notice = mText("Öppna Mumla. Sessionen är inte tillgänglig.", "Open Mumla. The session is unavailable.")
        }
    }
}
