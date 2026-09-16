# Acta native implementation

Acta shares Tapas’s floating home with Dictado. Open it from Tools or with
Control–Shift–M (configurable in Preferences). The shortcut opens controls; it
does not begin recording.

## Meeting suggestions

A local monitor reads Core Audio’s process list and
[`kAudioProcessPropertyIsRunningInput`](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput)
once a second. It does not request microphone permission or receive audio. It
attributes input to a running regular app by PID or bundle identity, including
identifiable browser helpers, and ignores Tapas. Unknown services are ignored
rather than attributed to whichever app happens to be in front.

After three seconds of activity, a non-activating Pintxo invitation offers Record
meeting (or Set up & record) / Not now. It stays until a response or the app stops
using input; there is no timer. An offer is
remembered for the current microphone-use episode; a minute without activity
rearms it. A global minute cooldown avoids a burst of unrelated prompts. Short
mute/reconnect gaps do not repeat the prompt. Detection is a heuristic, so the
copy states microphone use rather than asserting that a meeting was detected.

Suggestions work before setup/models are ready, defer during Dictado or setup,
and are suppressed while Acta is active or its controls are open. Accepting an
invitation starts microphone + computer audio capture when models and permissions
are ready, without taking focus from the call. Otherwise Acta opens its setup
controls. Allowing a permission never starts recording; Start Acta remains an
explicit action. The detected app is context for the prompt, not a capture filter.
No recording begins from detection alone. Preferences can disable suggestions and stop polling. Read errors surface
in Preferences and do not count as a meeting ending. There are no calendar,
meeting-service or MCP dependencies.

## Recording and ownership

- Explicit microphone and computer audio permission. Allow computer audio requests
  Screen & System Audio Recording access; background detection never requests it.
  There is no app picker. Computer audio includes other apps and notifications,
  excluding Tapas’s own audio. No screen output is registered or persisted.
- A ScreenCaptureKit stream captures computer audio and microphone separately.
  Native PCM formats are converted to 16 kHz mono per source. Five-second chunks
  keep audio memory bounded; recognition uses the existing local Voz/Ear pipeline.
- The shared home shows elapsed recorded time, input meters, transcript preview
  and Pause/Resume/Finish. All tools returns home without stopping capture. Leaving
  Acta closes the main window after capture starts and reveals the floating Pintxo.
  Pause/resume, elapsed time and finish controls stay visible below it. The timer
  opens details explicitly. Eight slim bars use recent measured loudness levels;
  about 700 ms of quiet lets them morph back into the original four-piece Pintxo.
  Pause also returns to the Pintxo, with a small pause badge. Reduced Motion skips
  the morph animation. Recording has no duplicate status label or extra card.
  Errors and recovery show details; background saves show a dismissible receipt.
- Pause stops the capture stream, flushes each source’s partial chunk and waits
  for queued journal writes. Resume creates a new stream with an accumulated
  recorded-time offset. Recognition already queued may finish while paused.
- Dictado reserves the microphone while it starts; Acta pauses before a take and
  stays paused afterward. Acta cannot start/resume during Dictado or setup.
- Stream/conversion errors pause the meeting. Closing a meeting app does not.
  Both inputs stop so users
  know the recording is incomplete. Waiting-for-audio indicators do not claim
  that quiet computer audio is disconnected. Resume can retry permissions/devices.

The capture implementation follows Apple’s [ScreenCaptureKit content
filters](https://developer.apple.com/documentation/screencapturekit/sccontentfilter)
and the SDK’s audio/microphone stream outputs on macOS 15+.

After saving, Acta shows a compact completion receipt with styled New meeting,
View transcript and Export Markdown actions. Opening Acta again returns to the
start screen; saved text is available through the explicit transcript action or
Recent. Live transcript previews scroll in a bounded area below the controls.
New computer audio segments use `systemAudio`; legacy `app` recovery segments
remain readable with their original labels.

## Files and recovery

The full, unredacted transcript is written to the shared folder’s `acta/`
subdirectory, regardless of Dictado’s history preference. The default is
`~/Documents/tapas/`. Onboarding and Preferences use the same native folder picker.
New recordings use a changed location; active takes and recovery retain their
original destination, and existing files are not moved. Markdown includes date, recorded duration,
languages, timestamped microphone/app-source segments and interruption notes.
Labels are sources, not speaker identities. Use headphones to reduce duplicate
voices caused by microphone pickup of app playback. No summarization or diarization.

Audio chunks and a JSON transcript journal are kept in
`~/Library/Application Support/Tapas/ActaRecovery/<session UUID>/`. The recovery
folder is created with owner-only permissions. Each audio chunk reaches disk
before inference; each recognized segment is checkpointed before its chunk is
removed. Completed chunk IDs make restart replay idempotent. Empty meetings save
an explicit no-speech note.

Failed inference/save leaves recovery available. Finish retries pending audio and
writes a stable unique output path, so retry does not add duplicate Recent files.
An interrupted session is loaded paused after model preparation. Export preserves
available recognized text, and explicit Discard removes its recovery. New meeting
surfaces any older unresolved journal first. Quit asks users to finish/recover or
discard an active session. An abrupt termination can lose the final unjournaled
chunk (up to five seconds per source); this is not a continuous archival recorder.

## Automated verification

```sh
swift test
swift test --package-path Apps/TapasApp
swift build --package-path Apps/TapasApp --product Tapas
Apps/TapasApp/.build/debug/Tapas --render-design /tmp/tapas-design
```

Core tests cover both input labels, paused audio rejection, recorded-time offsets,
no-speech output, failure/retry, restart with pending and recognized audio,
checkpoint-before-delete replay, discard, and protection from replacing an
unfinished meeting. Native tests exercise stereo app audio and native integer/
floating-point microphone formats, including sample-rate changes.

The debug renderer includes Acta preflight, recording, paused, recovery, saved and
companion views. Rendering uses sample data and never records audio.
