# Tapas

**Small tools. Good company.**

A plate of small, on-device AI tools for Mac. Dictation first. More later.

Built so Claude, Codex, and Cursor can use what you capture. Files in `~/Documents/tapas/` first, then a skill/MCP. The Mac app is not another chat.

Under the hood, a few [Desert Ant](https://desertant.com) models chained together. Nothing leaves the machine.

## The plate

| Tapa | What it is | Status |
| --- | --- | --- |
| **Dictado** | Local dictation, Gráfico onboarding, live words, paste recovery and Markdown history. | implemented; device verification pending |
| **Acta** | Meeting transcript with no bot in the call. Local file Claude or Codex can read. | next |
| **Captura** | "Screenshot this page" by voice. PNG + note in the Tapas folder. | later |
| **Consulta** | Voice file search on disk. | later |

Dictado transcribes 25 European languages on device (Voz / Parakeet TDT 0.6B v3): Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, Ukrainian.

## How the hotkey should feel

Press Control-Option (changeable in Preferences). A small overlay shows words as you talk. Press it again to finish, or Escape to cancel. Dictado sends the words to the original app and, if history is on, saves a redacted Markdown copy. Failed paste or save operations keep the text available for copy, export or retry.

**Orden** is the routing seam and currently always selects Dictado. Voice commands for Captura and Consulta are future work.

Desert Ant's Voz is NVIDIA Parakeet TDT 0.6B v3 on the Neural Engine. Live words come from transcribing at pauses, not from a streaming graph.

## Repo

Menu-bar app plus a testable `TapasCore` library. Xcode is not required.

```sh
swift test
Scripts/package-app.sh   # writes dist/Tapas.app
```

Open `dist/Tapas.app`, then finish **A first taste of Tapas**: microphone, optional Accessibility, voice-model preparation and a practice take. Accessibility enables the global shortcut and automatic paste. Without it, start from **Your plate** and copy finished words.

Click the pintxo in the menu bar for **Tools**, searchable **Recent** files and **Preferences**. Live words and history can each be switched off. History lands in `~/Documents/tapas/dictado/`; rapid takes receive unique filenames. Acta, Captura and Consulta remain future tools.

- [`NOTICE.md`](NOTICE.md) — Desert Ant license and attribution
- [Native implementation and verification](design/tapas/IMPLEMENTATION.md) — native code, test coverage and remaining device checks
- [Design direction and prototype](design/tapas/README.md) — Pintxo / Gráfico, onboarding and product behaviors

## License

Tapas itself has no license yet.

The models ship under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). Free under 100k monthly active devices per model on macOS. Credit in About: "Powered by Desert Ant Labs", link to https://desertant.com. Full notes in [`NOTICE.md`](NOTICE.md).
