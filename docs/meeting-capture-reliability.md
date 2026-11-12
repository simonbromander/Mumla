# Meeting capture: short callbacks and writer stalls

## Reproduced defect

The writer allocated 24 large PCM buffers, but consumed one whole slot for each
hardware callback. At 48 kHz with 128-frame callbacks, only 64 ms of pending
audio fit, despite most of the allocated sample storage being unused. A brief
disk/metadata delay could exhaust the pool and interrupt both-track recording.
The writer also discarded already-queued buffers once its failure flag was set.

A deterministic synthetic test suspends the writer for half a second of stereo
input on each track. Before the fix, neither track retained any samples: four
assertions failed. This demonstrates a real failure path, not the confirmed
cause of any particular user's recording. There is no 13-minute meeting limit.

## Fix

- Pack small callbacks into preallocated batches of at most 100 ms. Production
  capacity is normally 2.4 seconds of queued audio, with the existing 24 slots
  and unchanged allocation ceiling. Large callbacks split across batches.
- Flush the final partial batch on Stop/Pause. Keep source timing and bounded
  3-second mono PCM files for transcription.
- Overload stops accepting new input, but drains already-accepted audio. Actual
  file-write errors still stop further writes safely.
- Preserve a non-sensitive interruption reason in meeting metadata. Old JSON
  without the optional field still decodes.
- Unexpected stops show a recorder warning. Interrupted meeting documents keep
  an incomplete-recording notice even after transcription finishes or app restart.

No audio/text upload, new permission, automatic recording restart, source
broadening, unlimited queue or extra model is introduced. Missing audio after a
real recording stop cannot be reconstructed. If only transcription stopped,
saved audio can be transcribed again using the existing action.

## Acceptance

Regression checks cover small-callback stalls on both tracks, preservation of
accepted audio under true overload, hardware sample-rate conversion, partial
batch flushes, interruption warning versus normal-stop dismissal, and old/new
metadata decoding. The opt-in two-hour/two-track test validates disk-backed
chunking beyond the reported duration; it is synthetic, not a real call or a
real-time ASR/acoustic validation.

Actual incident attribution requires the affected device's recording/capture
state, source, saved audio end and transcript end. Do not upload meeting content
for diagnosis. Real hardware/call acceptance remains a separate release gate.

## Local results

- Reproduction failed before the fix and passes after it, with identical PCM
  samples to the unstalled control on both tracks.
- Full Swift suite: 339 tests, 9 optional skips, zero failures.
- Explicit two-hour/two-track writer check: 4,800 bounded chunks, full duration
  on each track, recovery check passed in approximately 168 seconds of test time.
  This is accelerated synthetic input, not two hours of real-time call capture.
- Direct Mac Debug build and Mac UI test target compile succeeded. Isolated
  minimum-window interaction/visual inspection confirmed the warning and partial
  status. Native XCTest UI execution remains unverified on this host; no new OS
  permission was granted to run it.
- No release published and no existing user meeting files modified.
