# Tapas

A plate of small, on-device AI tools for Mac. Dictation first. More later.

Built so Claude, Codex, and Cursor can use what you capture. Files in `~/Documents/tapas/` first, then a skill/MCP. The Mac app is not another chat.

Each tapa is a real Spanish word that also reads as English and names the job. [Naming rules](docs/naming.md). Under the hood, a few [Desert Ant](https://desertant.com) models chained together. Nothing leaves the machine.

## The plate

| Tapa | What it is | Status |
| --- | --- | --- |
| **Dictado** | Hotkey dictation. Overlay, paste into the focused app. | v1, in tree |
| **Acta** | Meeting transcript with no bot in the call. Local file Claude or Codex can read. | next |
| **Captura** | "Screenshot this page" by voice. PNG + note in the Tapas folder. | later |
| **Consulta** | Voice file search on disk. | later |

Dictado transcribes 25 European languages on device (Voz / Parakeet TDT 0.6B v3): Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, Ukrainian.

## How the hotkey should feel

Press Right ⌘. A small overlay shows words as you talk. Press Right ⌘ again. Every take goes through **Orden** (a feature, not a tapa): transcribe, then pick the tapa. Prose is Dictado and lands where the cursor is. "Create screenshot of this" is Captura. "Find me that PDF" is Consulta.

Desert Ant's Voz is NVIDIA Parakeet TDT 0.6B v3 on the Neural Engine. Live words come from transcribing at pauses, not from a streaming graph.

## Repo

Menu-bar app plus a testable `TapasCore` library. Xcode is not required.

```sh
swift test
Scripts/package-app.sh   # writes dist/Tapas.app
```

Press Right ⌘ to start, Right ⌘ again to paste. History lands in `~/Documents/tapas/dictado/`. First launch downloads Voz (~467 MB) and specialises it on the Neural Engine.

- [`docs/naming.md`](docs/naming.md) — how tapas get named
- [`NOTICE.md`](NOTICE.md) — Desert Ant license and attribution

## License

Tapas itself has no license yet.

The models ship under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). Free under 100k monthly active devices per model on macOS. Credit in About: "Powered by Desert Ant Labs", link to https://desertant.com. Full notes in [`NOTICE.md`](NOTICE.md).
