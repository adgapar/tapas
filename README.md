# Tapas

**Small tools. Good company.**

A plate of small, on-device AI tools for Mac. The first release brings together Dictado and Acta; both now have native implementations under device verification.

## Capture on your Mac. Keep your files. Build whatever comes next.

Tapas turns your words into readable local files. Use them with your favorite
coding agent, write a script, or build your own agent harness. Any tool that can
read files can work with your data.

**Your files are the interface.**

Saved transcripts belong to you, in plain Markdown under `~/Documents/tapas/`.
Open them in a text editor, point Claude Code or Codex at the folder, or build a
workflow we have never imagined. You choose which tools get access and where
their analysis runs.

Files come first; integrations are optional conveniences. Reading and using your
saved transcripts does not depend on a Tapas account, a proprietary API, an
export operation, or an MCP server. Future integrations should make the files
easier to use while keeping that direct access intact.

Under the hood, a few [Desert Ant](https://desertant.com) models chained together. Audio and transcripts are processed locally. Model downloads and SDK usage/licensing reporting use the network; see [privacy details](PRIVACY.md).

## Installable preview

**0.1.0 Preview 2** adds Acta and Sparkle automatic updates, for Apple silicon
Macs running macOS 15 or later. Release packaging supports Developer ID signing,
Apple notarization and a stapled DMG. Published builds appear on
[GitHub Releases](https://github.com/adgapar/tapas/releases).

Drag Tapas from the DMG into Applications and open it there. Future published
releases are checked and downloaded automatically; recording and recovery delay
restarting. Preferences includes update controls and **Check for Updates…**.
Existing development installs require this one manual installation.
See [installation instructions](docs/releases/INSTALL.txt),
[release notes](docs/releases/0.1.0-preview.2.md) and
[release/update setup](docs/SIGNING.md). The public update feed must be published
before update checks succeed.

Acta’s live-call accuracy and audio-device changes still need broader testing.
This remains a development preview.

## The plate

| Tapa | What it is | Status |
| --- | --- | --- |
| **Dictado** | Local dictation, Gráfico onboarding, live words, paste recovery and Markdown history. | implemented; device verification pending |
| **Acta** | Microphone + selected-app meeting transcripts, pause/resume, a persistent companion and recoverable Markdown files. | implemented; device verification pending |

Dictado transcribes 25 European languages on device (Voz / Parakeet TDT 0.6B v3): Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, Ukrainian.

## How the hotkey should feel

Press Control-Option (changeable in Preferences). El borde, a tiny four-color recording tab below the menu bar and camera, stays visible while you talk; live words appear separately when enabled. Press it again to finish, click the tab, or Escape to cancel. Hover over the tab for Finish / Cancel controls. Successful delivery briefly shows “Listo,” then hides it. Dictado sends the words to the original app and, if history is on, saves a redacted Markdown copy. Failed paste or save operations keep the text available for copy, export or retry.

**Orden** is the routing seam and currently always selects Dictado. Broader voice routing remains an uncommitted extension.

Desert Ant's Voz is NVIDIA Parakeet TDT 0.6B v3 on the Neural Engine. Live words come from transcribing at pauses, not from a streaming graph.

## Acta: keep the conversation

Acta offers to record when another identifiable app starts using the microphone.
Choose **Start Acta** to record that app, or **Not now** to dismiss. The prompt
waits for sustained microphone use and avoids repeats during brief mute/reconnect
gaps. Detection stays local and does not listen to audio. No calendar integration,
meeting account or MCP is required. Turn suggestions off in Preferences.

Open **Your plate → Acta**, allow microphone access, then use **Allow app audio & load apps** to select a running meeting app. macOS requests Screen & System Audio Recording access for app audio. For a browser meeting, select the browser; its other tabs may also be captured.

Start explicitly when everyone is ready to be recorded. Acta shows both audio inputs and recorded time. **Pause** stops both inputs; **Resume** is explicit. Closing the window leaves a floating companion with Open, Pause/Resume and Finish controls. Starting Dictado pauses Acta until you resume it.

**Finish & save** writes a full, unredacted, timestamped Markdown transcript to `~/Documents/tapas/acta/` and adds it to Recent. Microphone and app labels identify sources, not individual speakers. Headphones help avoid duplicate voices across the two inputs. Acta does not generate summaries or action items.

Pending audio and transcript checkpoints live in `~/Library/Application Support/Tapas/ActaRecovery/`. Interrupted meetings reopen paused after model preparation and can be finished, exported or discarded. A failed save keeps recovery available. Successful saves remove temporary audio. An abrupt crash can lose the last five seconds that have not yet reached the journal.

Native capture still needs live-call verification across meeting apps, permission states and audio devices. See [Acta implementation and checks](docs/ACTA.md).

## Repo

Menu-bar app plus a testable `TapasCore` library. Xcode is not required.

```sh
swift test
swift test --package-path Apps/TapasApp
Scripts/package-app.sh   # writes dist/Tapas.app
Scripts/package-dmg.sh   # packages a separate app into dist/releases/*.dmg
```

Open `dist/Tapas.app`, then finish **A first taste of Tapas**: microphone, optional Accessibility, voice-model preparation and a practice take. Accessibility enables the global shortcut and automatic paste. Without it, start from **Your plate** and copy finished words.

Click the pintxo in the menu bar for **Tools**, searchable **Recent** files and **Preferences**. Live words and history can each be switched off. History lands in `~/Documents/tapas/dictado/`; rapid takes receive unique filenames. Open **Acta** from Tools to record a meeting. The first public release waits for device verification of both tools.

- [Developer ID signing and notarization](docs/SIGNING.md) — certificate setup and release commands
- [Product and identity strategy](PRODUCT_STRATEGY.md) — two-tool launch, a stable four-ingredient mark, and room to grow
- [`NOTICE.md`](NOTICE.md) — Desert Ant license and attribution
- [Native implementation and verification](design/tapas/IMPLEMENTATION.md) — native code, test coverage and remaining device checks
- [Design direction and prototype](design/tapas/README.md) — Pintxo / Gráfico, onboarding and product behaviors
- [Product messaging](design/tapas/MESSAGING.md) — the product promise, landing-page copy and files-first principle

## License

Tapas itself has no license yet.

The models ship under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). Free under 100k monthly active devices per model on macOS. Credit in About: "Powered by Desert Ant Labs", link to https://desertant.com. Full notes in [`NOTICE.md`](NOTICE.md).
