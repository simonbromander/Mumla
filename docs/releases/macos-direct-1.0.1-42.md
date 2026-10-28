# Mumla for Mac 1.0.1 (42) - DJI Mic Button Beta

## New And Fixed

- Optional native DJI Mic Mini button control. Connect the receiver by USB,
  enable the DJI microphone button in Settings and allow Input Monitoring.
  A short button press starts hands-free dictation; another press finishes
  it using Mumla's existing transcription and paste workflow.
- The listener ignores other devices, duplicate reports and reported pairing
  holds. It pauses across sleep and handles receiver disconnection. If the
  separate DJI Mic Mumla helper is running, quit it before using native control.
- The menu-bar icon now matches Mumla's waveform and recording-button branding
  and follows the system's light/dark menu-bar appearance.

DJI control is off by default. The receiver button does not select the audio
input: choose your microphone separately in Settings. Microphone, Secure Input,
model readiness and paste protections still apply. Existing keyboard triggers,
Qwen formatting and summaries, history, dictionary and appearance remain.

## Install

Choose Check for Updates in the direct app, or download the notarized ZIP,
quit Mumla and replace the copy in Applications. Keep Microphone, Input
Monitoring and Accessibility enabled. Do not run direct and TestFlight copies
simultaneously. Existing models and local data are preserved.

This is a direct Mac beta for macOS 14+, on Apple silicon and Intel. Optional
Qwen text generation is Apple-silicon-only. Speech recognition remains Swedish
only; meetings and iCloud sync are not implemented. No cloud transcription
fallback. Licenses are available in About.

## Testing

Test short presses, start/stop, receiver disconnect/reconnect and sleep/wake
with a real DJI Mic Mini. Check the selected audio input, hotkeys, auto-paste
and clipboard restoration in your normal editor. Automated listener tests and
signed distribution checks do not establish physical receiver or live updater
acceptance. Watch voice notes ship in the separate iOS TestFlight beta.
