# Mac App Store Compatibility

Reviewed 2026-10-05. Technical compatibility and App Review approval are
separate gates; a successful TestFlight upload establishes neither.

## Current Boundary

Mac App Store apps must be sandboxed under guideline 2.4.5(i). TestFlight
betas must comply with the App Review Guidelines under 2.2, so TestFlight
is not an unrestricted distribution channel.
[Apple's guidelines](https://developer.apple.com/app-store/review/guidelines/).

Apple DTS confirms that sandboxed apps can use Input Monitoring with
`CGEventTap`. It does not support general Accessibility privileges in
sandboxed apps without temporary exception entitlements. DTS explicitly
separates its technical guidance from App Review policy.
[Apple's clarification](https://developer.apple.com/forums/thread/780626).

Mumla's current cross-app workflow requires Accessibility to capture and
validate the original focused field, exclude secure fields, read the field
after insertion, and observe corrections. `ClipboardTextInserter` deliberately
does not treat posting Cmd+V as proof that the paste succeeded. The current
implementation cannot be advertised as working unchanged in the sandboxed
Mac App Store/TestFlight target.

## Paste-Only Experiment

A minimal sandboxed prototype could test Input Monitoring and user-authorized
event posting without reading another app's text. This is a proposal, not a
verified capability or App Review approval. It cannot retain AX-based paste
verification, field inspection, or automatic correction learning unchanged.

Before offering auto-paste in a store build:

1. Build a separately signed sandboxed prototype using public APIs only.
2. Test real key delivery and paste in TextEdit, Notes, Mail, and browser fields,
   including secure input, focus changes, permissions, and clipboard restoration.
3. Define honest fallback behavior when successful insertion cannot be verified.
4. Seek Apple technical guidance and submit the documented workflow for review.

Do not add invented Accessibility entitlements, an unsandboxed helper, or a
downloaded executable as a way around review or platform restrictions.

## Distribution

Keep the full current Mac workflow in the signed, notarized Developer ID app.
Only that target embeds Sparkle. Store builds use Apple's update channel;
guideline 2.4.5(vii) disallows a separate updater in Mac App Store apps.
The iOS release remains a separate App Store/TestFlight workflow.
