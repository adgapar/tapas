# Tapas

**Small tools. Good company.**

A plate of small, on-device AI tools for Mac. The first release will include Dictado and Acta; development starts with Dictado.

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

**0.1.0 Preview 1** is the first packaged Dictado preview, for Apple silicon Macs running macOS 15 or later. The release is being prepared while Developer ID signing and notarization are set up. Published builds will appear on [GitHub Releases](https://github.com/adgapar/tapas/releases).

The current local DMG is ad-hoc signed and not notarized. macOS may require [Open Anyway](https://support.apple.com/102445) after the first attempted launch. Existing testers may need to re-add the installed copy to Accessibility. See [installation instructions](docs/releases/INSTALL.txt) and [draft release notes](docs/releases/0.1.0-preview.1.md).

Acta remains in development. The full product launch still waits for Dictado and Acta together.

## The plate

| Tapa | What it is | Status |
| --- | --- | --- |
| **Dictado** | Local dictation, Gráfico onboarding, live words, paste recovery and Markdown history. | implemented; device verification pending |
| **Acta** | Meeting transcript with no bot in the call. Local file Claude or Codex can read. | planned for first release; design preview |

Dictado transcribes 25 European languages on device (Voz / Parakeet TDT 0.6B v3): Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, Ukrainian.

## How the hotkey should feel

Press Control-Option (changeable in Preferences). El borde, a tiny four-color recording tab below the menu bar and camera, stays visible while you talk; live words appear separately when enabled. Press it again to finish, click the tab, or Escape to cancel. Hover over the tab for Finish / Cancel controls. Successful delivery briefly shows “Listo,” then hides it. Dictado sends the words to the original app and, if history is on, saves a redacted Markdown copy. Failed paste or save operations keep the text available for copy, export or retry.

**Orden** is the routing seam and currently always selects Dictado. Broader voice routing remains an uncommitted extension.

Desert Ant's Voz is NVIDIA Parakeet TDT 0.6B v3 on the Neural Engine. Live words come from transcribing at pauses, not from a streaming graph.

## Repo

Menu-bar app plus a testable `TapasCore` library. Xcode is not required.

```sh
swift test
Scripts/package-app.sh   # writes dist/Tapas.app
Scripts/package-dmg.sh   # packages a separate app into dist/releases/*.dmg
```

Open `dist/Tapas.app`, then finish **A first taste of Tapas**: microphone, optional Accessibility, voice-model preparation and a practice take. Accessibility enables the global shortcut and automatic paste. Without it, start from **Your plate** and copy finished words.

Click the pintxo in the menu bar for **Tools**, searchable **Recent** files and **Preferences**. Live words and history can each be switched off. History lands in `~/Documents/tapas/dictado/`; rapid takes receive unique filenames. Acta is still in development; the first public release waits for both tools.

- [Product and identity strategy](PRODUCT_STRATEGY.md) — two-tool launch, a stable four-ingredient mark, and room to grow
- [`NOTICE.md`](NOTICE.md) — Desert Ant license and attribution
- [Native implementation and verification](design/tapas/IMPLEMENTATION.md) — native code, test coverage and remaining device checks
- [Design direction and prototype](design/tapas/README.md) — Pintxo / Gráfico, onboarding and product behaviors
- [Product messaging](design/tapas/MESSAGING.md) — the product promise, landing-page copy and files-first principle

## License

Tapas itself has no license yet.

The models ship under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). Free under 100k monthly active devices per model on macOS. Credit in About: "Powered by Desert Ant Labs", link to https://desertant.com. Full notes in [`NOTICE.md`](NOTICE.md).
