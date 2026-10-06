#if os(iOS)
import notify
import Foundation

/// A payload-free hint to re-read the protected App Group files, never a command itself.
public final class KeyboardSessionSignal: Sendable {
    public enum Channel: String, Sendable {
        case command, state
        fileprivate var name: String { "group.com.mumla.app.keyboard.\(rawValue)" }
    }

    private let token: Int32

    public init?(_ channel: Channel, onChange: @escaping @Sendable () -> Void) {
        var token: Int32 = 0
        let status = notify_register_dispatch(channel.name, &token, .main) { _ in onChange() }
        guard status == NOTIFY_STATUS_OK else { return nil }
        self.token = token
    }

    deinit { notify_cancel(token) }

    public static func post(_ channel: Channel) { notify_post(channel.name) }
}
#endif
