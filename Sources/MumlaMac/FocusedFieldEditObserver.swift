import Foundation
import MumlaCore

@MainActor
final class FocusedFieldEditObserver {
    private var task: Task<Void, Never>?
    private let captureDelayNanoseconds: UInt64
    private let observationDelayNanoseconds: UInt64

    init(
        captureDelayNanoseconds: UInt64 = 800_000_000,
        observationDelayNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.captureDelayNanoseconds = captureDelayNanoseconds
        self.observationDelayNanoseconds = observationDelayNanoseconds
    }

    func start(
        learner: CorrectionLearner,
        learned: @escaping @MainActor (DictionaryEntry) -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: captureDelayNanoseconds)
            guard
                !Task.isCancelled,
                let originalValue = FocusedTextTargetInspector.focusedEditableValue()
            else {
                return
            }

            try? await Task.sleep(nanoseconds: observationDelayNanoseconds)
            guard
                !Task.isCancelled,
                let editedValue = FocusedTextTargetInspector.focusedEditableValue(),
                editedValue != originalValue
            else {
                return
            }

            if case let .learned(entry) = learner.observe(
                originalText: originalValue,
                editedText: editedValue
            ) {
                learned(entry)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
