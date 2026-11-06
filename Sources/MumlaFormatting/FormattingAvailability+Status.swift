import MumlaUI

public extension FormattingAvailability {
    var textModelStatus: String {
        switch self {
        case .available: mText("Redo på den här enheten", "Ready on this device")
        case .systemTooOld: mText("Kräver iOS 26 eller macOS 26.", "Requires iOS 26 or macOS 26.")
        case .deviceNotEligible: mText("Enheten stöder inte modellen.", "This device doesn't support the model.")
        case .intelligenceDisabled: mText("Apple Intelligence är avstängt.", "Apple Intelligence is turned off.")
        case .modelNotReady: mText("Apples modell är inte redo.", "Apple's model isn't ready.")
        case .unsupportedLanguage: mText("Modellen stöder inte det aktuella språket.", "The model doesn't support the current language.")
        case .modelNotInstalled: mText("Textmodellen är inte installerad.", "The text model isn't installed.")
        }
    }
}
