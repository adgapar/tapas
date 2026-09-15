# Tapas preview privacy

Dictado processes microphone audio and transcripts on your Mac. Tapas does not
upload recordings, dictated text or saved history for transcription or rewriting.
There is no Tapas account or cloud transcript store.

## What stays on your Mac

- Audio is held in memory for a take; Tapas does not save audio recordings.
- Dictated text is sent to the destination app. If clipboard fallback is needed,
  Tapas temporarily uses the system clipboard and restores its prior contents
  unless you copied something else meanwhile.
- Optional history is saved as redacted Markdown in `~/Documents/tapas/dictado/`.
  Redaction can make mistakes. Pasted and explicitly copied/exported text retains
  the recognized words.
- Preferences, downloaded voice models and recent-history files remain local.
- Failed delivery retains text in memory for copy, export or retry. Unsaved
  recovery does not survive quitting or a crash.
- Local diagnostic logs record permission/shortcut status, microphone format and
  audio levels, not dictated words. The preview writes `/tmp/tapas.log` and uses
  the macOS logging system.

The destination application, clipboard managers and any services syncing your
chosen folders have their own handling of the text you give them.

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

This preview does not add a separate Tapas analytics or crash-upload service.
Dependency details and attribution are in [NOTICE.md](NOTICE.md). This notice
describes the current Dictado preview; Acta is not implemented.
