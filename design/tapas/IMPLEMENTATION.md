# Gráfico · Native Dictado

The brand and visual direction remain in [README.md](README.md); [BEHAVIORS.md](BEHAVIORS.md) records the broader product strategy. The browser prototype is a reference. The native implementation is SwiftUI and AppKit, connected to local speech recognition.

## Implemented surfaces

- **First taste:** Gráfico setup window, microphone access, optional Accessibility, voice-model preparation and retry, real dictation practice, completion. Setup can be closed and resumed. Models download during setup; a completed installation prepares cached models on launch.
- **Your plate:** pintxo menu-bar icon, Dictado start/finish, persistent status, Tools / Recent / Preferences, file opening and Finder reveal. Acta is marked Next; Captura and Consulta are Later. Future tools have no active capture behavior.
- **Dictado:** non-activating recording indicator, optional live words, finishing state, Escape cancellation, permission and transcription errors, retained results with copy/export and separate paste/save retries. Turning off Show live words keeps a compact Starting / Listening / Finishing panel with recording controls; it hides only the transcript preview. Setup and Your plate show their own recording status while open. Recovery still displays retained words regardless of this preference.
- **Preferences:** Control–Option, Right Command or a recorded custom shortcut; live transcript preview; history saving. Preferences survive relaunch. Permission state reflects macOS rather than a simulated toggle.
- **Identity:** shared colors and pintxo drawing in `Grafico.swift`, reduced-motion support, generated app icon, main tagline “Small tools. Good company.”

## Accessibility setup recovery

The Accessibility step always keeps a Continue action visible. If macOS has not confirmed permission, “Continue with copy” advances setup without enabling automatic paste or the global shortcut. The step rechecks permission when its window becomes key and through Check again; a successful explicit check also retries global shortcut registration.

Open Settings asks macOS to register the running app's permission request before opening the Accessibility pane. If an enabled entry is not recognized, the UI explains how to toggle it or replace the old entry, and Show this Tapas in Finder identifies the current app bundle. Locally rebuilt, ad-hoc-signed apps may need permission to be granted again; an enabled Settings entry alone is not treated as proof of access.

The global shortcut uses an Accessibility-authorized event tap (`defaultTap`) and passes events through unchanged. The previous `listenOnly` mode used the Input Monitoring permission path, even though setup requested Accessibility. Local shortcut practice alone does not verify global operation. Tap health checks now inspect validity and enabled state, retry failed registration at five-second intervals while trusted, and retry immediately when the shortcut changes or access is explicitly rechecked. Registration logs contain status only, never captured keys.

## Dictation and files

A take uses the microphone and local Voz recognition, with Ear language detection and English filler removal. Orden currently always selects Dictado. Acta and the other future tools are not routed from speech yet.

Model integrity checks happen during preparation, and the loaded language, filler and redaction models are reused across takes. Readiness checks on the shortcut path use the prepared state rather than re-hashing model files.

Live transcription passes are serialized with finalization. A canceled take cannot be revived by a late live result. The recorder retains the full converted audio until the take finishes, so pending UI updates cannot truncate the final pass. Short or silent takes produce an explicit message and no paste/history file. Audio is not saved.

At the start of a take, the app remembers the destination application. It tries Accessibility insertion first, then a clipboard / Command–V fallback. The fallback restores all clipboard representations unless the user copied something else meanwhile. If the destination app changed, the text is retained for recovery instead of being sent to the wrong app. Retry paste explicitly returns to the original destination.

Pasting and history saving are independent. A failed paste still allows a history copy; a failed history write does not prevent paste. A retained recovery result must be recovered or explicitly dismissed before starting a new take. Retrying history does not duplicate an already saved file.

History is redacted through Redact; pasted and explicitly copied/exported words retain what the person said. Redact is prepared with the other models so the first saved take does not trigger a surprise download. Files live in `~/Documents/tapas/dictado/`. The familiar minute-based filename is retained, with a unique suffix when another take uses the same name. Exclusive file creation prevents overwrite even across concurrent writers.

Closing the practice window cancels an active practice take; an already finishing practice pass remains in practice mode. Practice takes are not written to history. Closing Your plate does not stop a daily take. Finishing runs independently of the overlay.

## Main implementation locations

| Concern | Files |
| --- | --- |
| Identity and controls | `Apps/TapasApp/Sources/TapasApp/Grafico.swift` |
| Onboarding | `SetupView.swift`, `SetupWindowController.swift` in the app sources |
| Home and preferences | `PlateView.swift`, `MenuBarController.swift` in the app sources |
| Recording UI | `OverlayPanel.swift` in the app sources |
| App coordination | `AppDelegate.swift`, `HotkeyMonitor.swift`, `MicRecorder.swift`, `AccessibilityPaster.swift` in the app sources |
| State and files | `Sources/TapasCore/DictationSession.swift`, `HistoryWriter.swift`, `HistoryLibrary.swift` |

## Verification and remaining device checks

59 automated core tests pass. They cover delivery, independent paste/save recovery, history off, preference changes during a take, cancellation with delayed inference, no-speech handling, concurrent file creation, history parsing, shortcut matching and clipboard restoration on failure. Synthetic English, Spanish and Russian audio also passed through the real cached model pipeline: each produced the expected delivery text, correct `en` / `es` / `ru` metadata and a Markdown file in a temporary directory. These checks use a fixture paster, not the microphone or another app.

One model-quality issue was observed: Redact treated the Russian word “Давайте” as a given name in the saved copy. The delivered transcript remained correct. Redacted history is not a verbatim transcript; inspect multilingual redaction quality before relying on it as an exact record.

The native app builds with Swift Package Manager. Deterministic renders of the actual native views cover all setup phases, the home tabs and Dictado status/recovery.

Build and run:

```sh
swift test
Scripts/package-app.sh
open dist/Tapas.app
```

The package script generates the icon and signs the local development bundle ad hoc. Distribution signing and notarization are separate release work.

For native layout review without microphone capture or user files:

```sh
swift build --package-path Apps/TapasApp --product Tapas -Xswiftc -O
Apps/TapasApp/.build/debug/Tapas --render-design /tmp/tapas-native-renders
```

The debug build also supports `--verify-dictado <audio-file> <temporary-history-folder>` to run a supplied fixture through the real cached models and a fixture paste destination. This mode refuses to download missing models; `--prepare-models` is an explicit developer command to download and prepare them through the onboarding pipeline. Keep `-Xswiftc -O` for this check: the dependency’s unoptimized model checksum code is very slow.

Before treating this as a daily-driver release, verify on the Mac with its real OS permissions:

1. Complete setup and dictate a sentence into the practice field.
2. Dictate into Notes and another everyday app, including a field that needs the clipboard fallback.
3. Confirm the global shortcut and Escape cancellation with Show live words enabled and disabled. With it off, the compact recording indicator and Finish / Cancel controls must remain visible, while the transcript preview stays hidden.
4. Check that changing the destination during a take leads to text recovery; test copy and retry paste.
5. Dictate consecutive EN/ES/RU takes, inspect the redacted files, and relaunch to verify preferences and recent history.

The desktop verification driver currently lacks macOS Accessibility and Screen Recording permissions, so live device capture and cross-app insertion have not been verified by the agent. In-process view renders and mocked audio tests are not substitutes for that check. Synthetic Command–V delivery cannot confirm that every receiving app accepted the paste. Unsaved recovery text remains in memory until copied, exported or saved; it does not survive app termination.
