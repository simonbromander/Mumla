import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isRequested: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unavailable:
            return false
        }
    }

    var title: String {
        switch self {
        case .disabled:
            return "Off"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Needs approval"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum LaunchAtLoginController {
    static func currentStatus() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    static func setEnabled(_ isEnabled: Bool) throws -> LaunchAtLoginStatus {
        if isEnabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }

        return currentStatus()
    }
}
