# Tapas privacy

Dictado and Acta process audio and transcripts on your Mac. Tapas does not
upload recordings, dictated text or saved history for transcription or rewriting.
There is no Tapas account or cloud transcript store.

## What stays on your Mac

- Dictado audio is held in memory for a take; Dictado does not save recordings.
- Dictated text is sent to the destination app. If clipboard fallback is needed,
  Tapas temporarily uses the system clipboard and restores its prior contents
  unless you copied something else meanwhile.
- Optional history is saved as redacted Markdown in `~/Documents/tapas/dictado/`.
  Redaction can make mistakes. Pasted and explicitly copied/exported text retains
  the recognized words.
- Preferences, downloaded voice models and recent-history files remain local.
- Dictado failed delivery retains text in memory for copy, export or retry. Unsaved
  recovery does not survive quitting or a crash.
- Local diagnostic logs record permission/shortcut status, microphone format and
  audio levels, not dictated words. Tapas writes `/tmp/tapas.log` and uses
  the macOS logging system.

The destination application, clipboard managers and any services syncing your
chosen folders have their own handling of the text you give them.

## Meeting suggestions

When “Suggest Acta when the microphone is in use” is enabled, Tapas checks local
macOS process activity flags about once a second to identify apps with active
microphone input. Detection does not open the microphone or read audio. App
activity and dismissal state stay in memory; no activity history is saved or sent
elsewhere. This can detect microphone use that is not a meeting.

A suggestion offers Start Acta or Not now. Recording begins only after Start Acta
and any required permissions. Turn suggestions off in Preferences to stop these
checks. No calendar, meeting-service account, integration or MCP is needed.

## Acta meeting files and recovery

Acta records your microphone and computer audio, excluding Tapas’s own audio.
Computer audio can include other apps, browser tabs, music and notifications.
The app uses macOS ScreenCaptureKit permission for this; it does not retain screen images.
Pause stops both audio inputs. Start only when participants are ready to be recorded.

Acta saves full, unredacted Markdown transcripts under `~/Documents/tapas/acta/`,
independently of the Dictado history preference. These contain timestamps,
source labels, detected languages and recording interruption notes. Source labels
are not speaker identification. No summaries or action items are generated.

For restart and save recovery, Acta temporarily stores short audio chunks and
transcript checkpoints in `~/Library/Application Support/Tapas/ActaRecovery/`.
These files contain meeting content and are not encrypted by Tapas. Recognized
chunks are removed after their text is checkpointed. Successful saves or an
explicit Discard meeting remove the session’s remaining recovery files.
Failed/interrupted sessions retain them until resolved. An abrupt crash can lose
up to the last five seconds before the next chunk is journaled.

## Transcript discovery and assistant skills

The transcript folder is selectable in Preferences; the paths above are defaults.
Tapas writes local discovery indexes containing recording dates, durations, titles
when supplied, and short excerpts of saved text. Dictado previews use its redacted
saved text; Acta previews contain unredacted meeting text. Indexes live beside the
transcripts and are subject to the same folder-sync services you choose.

`~/Library/Application Support/Tapas/library.json` stores the current transcript
folder path and previously selected paths. Changing folders does not move files
or remove older folders from discovery. Active and recovered recordings retain
their original destinations.

Installing a Tapas assistant skill writes local instructions for finding and citing
recordings. It does not upload transcripts or grant file access. Your independently
chosen assistant may process text it reads through its own provider and settings.
Removing a skill does not remove transcripts, indexes, or the location setting.

## Network use

Setup downloads model files through the Desert Ant SDK. The app can reuse those
downloaded models for local inference. Opening external support or attribution
links also uses your browser and network.

Desert Ant’s SDK sends usage/licensing metadata to Desert Ant. Its reporting
includes an installation identifier, application and SDK identifiers, platform,
model-use information and timestamps. It supports active-device accounting;
it is not limited to one request per month. Audio and transcript content are not
part of this reporting. Ordinary network requests also expose connection
information, such as the IP address, to the receiving service.

Tapas does not add a separate Tapas analytics or crash-upload service.
Dependency details and attribution are in [NOTICE.md](NOTICE.md). This notice
describes the current source implementation. The historical 0.1.0 Preview 1
package contains Dictado only.

## App updates

Tapas uses Sparkle to check a public GitHub release feed and download signed
updates over HTTPS. GitHub receives normal network request information (including
your IP address); Sparkle sends its updater and app version in the user agent.
System profiling is disabled. No audio, transcripts or meeting metadata are sent
for updates. Automatic checks and downloads can be disabled in Preferences.
