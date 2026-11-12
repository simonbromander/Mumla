# Meetings UI polish

Scope: Mac meeting setup, saved/live transcripts, source/speaker/action popovers,
correction and deletion sheets. Keep recording, local transcription, storage,
permissions and export formats unchanged. Independent of destination sending.

- At compact window widths, move the inner meeting library into a picker so the
  main sidebar does not squeeze the transcript between two narrow columns.
- Wrap full meeting titles, source/speaker names, errors and processing status.
  Keep recording controls pinned and let document content scroll independently.
- Use Mumla's monospaced type, machined keys, recessed fields, LCD readouts and
  download gauge. Give menu triggers real key faces and consistent hit areas.
- Use branded edit/delete sheets with explicit Cancel, visible consequences,
  inline errors and no destructive default keyboard shortcut. Confirm audio-only
  deletion too. Keep macOS permission and file-save panels native.
- Verify synthetic empty, saved, live/paused, long-text, filtered and error states
  at 820x560, 960x760 and larger sizes in both appearances. Test correction and
  deletion behavior without microphone access or real meeting data.

No meeting recording, networking, model download or release is needed to inspect
the new UI. Synthetic screenshots are layout checks, not real-call acceptance.

## Verification

Local verification on 2026-11-11:

- Swift package suite: 310 tests, nine existing optional model/hardware skips,
  zero failures. Includes sheet sizing in both appearances, correction validation,
  stale-edit protection and audio deletion preserving text and speaker names.
- Direct Mac native build and the new `MumlaMeetingsUI` test build succeeded.
- Rendered 22 native screenshots covering setup, regular/long transcripts,
  compact/wide layouts, live/paused/error states and edit/delete/quit panels in
  light and dark appearances. Checked at 820x560, 960x760 and 1280x860.
  Also checked a Swedish compact transcript with long meeting and speaker names.
- In the isolated preview, manually verified action/source popovers, correction
  save, deletion cancellation, empty search results, pause/stop and the quit flow.
  Cancelling quit preserved the active session. Save and Quit ended the app and
  persisted the synthetic session with `capture: saved`.
- The automated Mac click-through runner compiled, but execution requires local
  UI Automation approval. Its authentication prompt was cancelled without granting
  permissions. Those automated UI scenarios are not recorded as passing.

The preview uses its own app identity, temporary stores, synthetic transcript data
and a silent capture implementation. It never activates the microphone or global
hotkey listener, uses real meeting data, or downloads models. Production app
identities, release versions and distribution permissions are unchanged.
