# Acta native implementation

Acta is available from Your plate → Tools. This is a development implementation;
0.1.0 Preview 1 remains the historical Dictado-only package.

## Meeting suggestions

A local monitor reads Core Audio’s process list and
[`kAudioProcessPropertyIsRunningInput`](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput)
once a second. It does not request microphone permission or receive audio. It
attributes input to a running regular app by PID or bundle identity, including
identifiable browser helpers, and ignores Tapas. Unknown services are ignored
rather than attributed to whichever app happens to be in front.

After three seconds of activity, a non-activating panel offers Start Acta / Not
now. It dismisses after 30 seconds or when the app stops using input. An offer is
remembered for the current microphone-use episode; a minute without activity
rearms it. A global minute cooldown avoids a burst of unrelated prompts. Short
mute/reconnect gaps do not repeat the prompt. Detection is a heuristic, so the
copy states microphone use rather than asserting that a meeting was detected.

Suggestions wait until setup/models are ready, defer during Dictado, and are
suppressed while Acta is active or its window is open. Start Acta rechecks the
suggested app against capturable sources and completes required permissions;
it never selects a different app as fallback. No recording begins from detection
alone. Preferences can disable suggestions and stop polling. Read errors surface
in Preferences and do not count as a meeting ending. There are no calendar,
meeting-service or MCP dependencies.

## Recording and ownership

- Explicit microphone permission and app selection. App enumeration requests
  Screen & System Audio Recording access via ScreenCaptureKit. Browser selection
  can include other tabs. No screen output is registered or persisted.
- A ScreenCaptureKit stream captures the selected app and microphone separately.
  Native PCM formats are converted to 16 kHz mono per source. Five-second chunks
  keep audio memory bounded; recognition uses the existing local Voz/Ear pipeline.
- The window shows elapsed recorded time, input meters, transcript preview and
  Pause/Resume/Finish. Closing or minimizing it leaves a floating companion.
- Pause stops the capture stream, flushes each source’s partial chunk and waits
  for queued journal writes. Resume creates a new stream with an accumulated
  recorded-time offset. Recognition already queued may finish while paused.
- Dictado reserves the microphone while it starts; Acta pauses before a take and
  stays paused afterward. Acta cannot start/resume during Dictado or setup.
- Stream/conversion errors and termination of the selected app pause the meeting.
  Unlike the HTML study’s microphone-only fallback, both inputs stop so users
  know the recording is incomplete. Waiting-for-audio indicators do not claim
  that a silent app is disconnected. Reopen the app and start a new meeting if
  its process has changed; resume can retry permissions/devices for the same app.

The capture implementation follows Apple’s [ScreenCaptureKit content
filters](https://developer.apple.com/documentation/screencapturekit/sccontentfilter)
and the SDK’s audio/microphone stream outputs on macOS 15+.

## Files and recovery

The full, unredacted transcript is written to `~/Documents/tapas/acta/`, regardless
of Dictado’s history preference. Markdown includes date, recorded duration,
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

## Required live-device checks

- Start a call in a browser, Zoom or Teams: verify app attribution, a single
  suggestion, dismissal/timeout, mute/reconnect suppression and preference opt-out.
  Unknown system helpers may require manually starting Acta.
- Allow/deny/revoke microphone and Screen & System Audio Recording access in the
  packaged app; verify actionable recovery and no recording before Start.
- Browser meeting, Zoom and Teams: verify the selected app and microphone both
  reach the transcript, unrelated apps do not, and app moves between displays do
  not unexpectedly lose audio. Check browser helper-process audio specifically.
- Pause/resume repeatedly; Dictado from hotkey and Tools; rapid competing starts;
  check that paused audio never appears and recorded time excludes pauses.
- Headset/default-device changes, app exit, sleep/wake, OS capture-stop controls,
  denied permissions and silent inputs: verify status and retained partial audio.
- A long meeting: measure recognition lag, memory/disk growth and word accuracy
  around five-second boundaries. Chunked recognition can split words/sentences.
- Close/minimize the window, change Spaces, finish from the companion, open the
  saved file from Recent, and retry a denied Documents write.
- Force termination after a checkpoint: reopen, recover and finish without
  duplicate segments; verify successful saves/discards remove recovery audio.

These hardware/permission/live-call checks have not been automated or certified.
