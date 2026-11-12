# Meeting capture: bounded buffering and conversion

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

The reported incident was narrowed to recording itself stopping while the
System audio source was selected. That excludes a transcript-only stall and
the per-application "meeting app closed" stop condition. No visible error,
sleep or device disconnection was reported. The exact cause is not established.

Production-capacity stereo tests also reproduced missing converted samples and
different PCM depending on callback layout and writer scheduling. The converter
can retain supplied memory after a conversion call returns; that memory must
not be recycled to capture before the converter requests more input. Conversion
output and the final resampler tail must also be drained, not discarded.

## Fix

- Pack small callbacks into preallocated batches of at most 100 ms. Production
  capacity is normally 2.4 seconds of queued audio, with the existing 24 slots
  and unchanged capture-pool allocation. Large callbacks split across batches.
- Give the converter one separate, bounded input buffer per track. Refill it
  only in its input callback, drain available output, and flush the tail on
  Stop/Pause. The additional buffer is 128 KiB per stereo Float32 track at the
  production capacity of 16,384 frames; allocation does not grow with duration.
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

Additional system-audio coverage uses interleaved stereo input at 44.1/48 kHz,
with 128-, 1,024- and 16,384-frame callbacks and the production buffer capacity.
It checks the full expected output frame count, exact buffered-versus-unstalled
PCM, and agreement with the non-interleaved control within PCM16 quantization.
The opt-in long test keeps each writer and converter alive for two hours of
accelerated input: 44.1 kHz non-interleaved microphone and 48 kHz interleaved
system audio, both stereo, using production buffer capacities.

Actual incident attribution requires the affected device's recording/capture
state, source, saved audio end and transcript end. Do not upload meeting content
for diagnosis. Real hardware/call acceptance remains a separate release gate.

## Local results

- Reproduction failed before the fix and passes after it, with identical PCM
  samples to the unstalled control on both tracks.
- Production-capacity interleaved conversion regression failed before the
  ownership/draining fix and passes after it, including exact frame counts.
- Combined-branch Swift suite: 356 tests, 9 optional skips, zero failures.
- Explicit two-hour/two-track writer check: 4,800 bounded chunks, full duration
  on each track, recovery check passed in approximately 286 seconds of test time.
  Each writer remains active across the full two-hour input, with resampling
  from 44.1/48 kHz and interleaved system audio rather than minute-long resets.
  This is accelerated synthetic input, not two hours of real-time call capture.
- Direct and sandboxed Mac Debug builds succeeded. The Mac UI test target also
  compiled. Isolated
  minimum-window interaction/visual inspection confirmed the warning and partial
  status. Native XCTest UI execution remains unverified on this host; no new OS
  permission was granted to run it.
- No release published and no existing user meeting files modified.
