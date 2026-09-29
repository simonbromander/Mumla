import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
public enum MumlaFeedback {
    #if os(iOS)
    private static let latchGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif
    public static let preferenceKey = "mumla.hapticsEnabled"
    public static var enabled: Bool { UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true }

    public static func press() {
        #if os(iOS)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.45)
        #endif
    }
    public static func selection() {
        #if os(iOS)
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    public static func prepareLatch() {
        #if os(iOS)
        guard enabled else { return }
        latchGenerator.prepare()
        #endif
    }
    public static func latch() {
        #if os(iOS)
        guard enabled else { return }
        latchGenerator.impactOccurred(intensity: 1)
        #endif
    }
    public static func recordStart() {
        #if os(iOS)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.85)
        #endif
    }
    public static func recordStop() {
        #if os(iOS)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.75)
        #endif
    }
    public static func success() {
        #if os(iOS)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    public static func error() {
        #if os(iOS)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
