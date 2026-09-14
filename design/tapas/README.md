# Tapas · Pintxo / Gráfico

The selected design direction: modern, playful local AI tools, represented by four faceless ingredients on one shared pick. Character comes from the shapes and their movement. This is the single maintained design prototype; the earlier visual comparisons have been removed.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --directory design/tapas
```

Open [the prototype](http://localhost:8765/). No build step, dependencies or external assets are needed.

Use the journey rail to explore onboarding, Dictado, Acta, Your plate, Captura and Consulta. The scenario picker introduces permission, connection, paste and save failures. Start an Acta session and switch to another journey to explore its persistent status. Reset demo or reload to start over.

## Selected visual language

| Element | Treatment |
| --- | --- |
| Identity | Four distinct pieces, one tilted pick, no face |
| Ingredients | Saffron `#f0c740`, cobalt `#3355c6`, paprika `#e65f3b`, olive `#81934f` |
| Outlines | Ink `#303b2b`, precise offset shadows |
| Surfaces | Warm paper, restrained borders, generous space |
| Typography | Direct sans-serif headings with occasional italic serif accents |
| Personality | Brief, purposeful motion; warm copy with a little Spanish flavor |

The pintxo assembles during setup, separates while listening, shifts while working and settles when output arrives. Status also has a text label, so motion and color are never the only signal. Reduced-motion preferences are respected.

## Files

- [index.html](index.html): prototype shell and journey navigation.
- [style.css](style.css): Gráfico design, motion and responsive layouts.
- [app.js](app.js): connected interactions and sample content.
- [icon.svg](icon.svg): selected faceless pintxo mark.
- [BEHAVIORS.md](BEHAVIORS.md): flow decisions, recovery behavior and native implementation boundaries.

This is a browser design prototype, not a native-app implementation. Speech, permissions, model preparation, app audio, capture and file search are simulated. Sample data and preferences stay in memory until reload. Explicit export buttons download sample Markdown; copy buttons use the browser clipboard. Nothing records audio or reads your folders.

Dictado is the first product. Acta is next; Captura and Consulta are later concepts, labeled accordingly throughout the preview.
