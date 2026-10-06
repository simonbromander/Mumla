import MumlaCore
import MumlaUI
import SwiftUI
import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let client = KeyboardClient()
    private var host: UIHostingController<KeyboardRoot>?
    private var heightConstraint: NSLayoutConstraint?
    private var visible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        primaryLanguage = "sv"
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
        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = .init(999); height.isActive = true
        heightConstraint = height; self.host = host
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); visible = true
        client.returnTitle = returnTitle
        client.start(fullAccess: hasFullAccess); updateHeight()
    }
    override func viewWillDisappear(_ animated: Bool) {
        visible = false; client.pause()
        super.viewWillDisappear(animated)
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); updateHeight() }
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        client.fullAccess = hasFullAccess
        client.returnTitle = returnTitle
        receiveResult()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning(); client.samples = []; client.result = nil
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
                textDocumentProxy.insertText(result.text)
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
        let height: CGFloat = landscape ? 266 : client.result == nil ? 300 : 342
        if heightConstraint?.constant != height { heightConstraint?.constant = height }
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
    weak var controller: KeyboardViewController?
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
            onKey: { controller?.textDocumentProxy.insertText($0) },
            onDelete: { controller?.textDocumentProxy.deleteBackward() },
            onReturn: { controller?.textDocumentProxy.insertText("\n") })
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

    func start(fullAccess: Bool) {
        pause(); self.fullAccess = fullAccess
        store = fullAccess ? KeyboardSessionStore.shared() : nil
        refresh()
        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                self?.refresh()
            }
        }
    }
    func pause() { task?.cancel(); task = nil }
    func send(_ action: KeyboardSessionCommand.Action, documentID: UUID? = nil, resultID: UUID? = nil) {
        guard fullAccess, pending == nil, let store, let id = snapshot.sessionID, snapshot.isAlive() else { return }
        let command = KeyboardSessionCommand(sessionID: id, action: action, requestID: snapshot.requestID,
                                             documentID: documentID, resultID: resultID)
        guard snapshot.accepts(command) else { return }
        do {
            try store.send(command); pending = command; notice = nil
            if action == .start { requestID = command.id }
        } catch { notice = mText("Öppna Mumla för att starta om sessionen.", "Open Mumla to restart the session.") }
    }
    private func refresh() {
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
            onRefresh?()
        } catch {
            snapshot = .init(); result = nil; pending = nil; requestID = nil
            notice = mText("Öppna Mumla. Sessionen är inte tillgänglig.", "Open Mumla. The session is unavailable.")
        }
    }
}
