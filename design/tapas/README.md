# Tapas · Pintxo / Gráfico

**Small tools. Good company.**

Tapas’s main brand line pairs the usefulness of small AI tools with the warmth of sharing tapas. Use this wording consistently; uppercase and a line break between the sentences are welcome in visual layouts.

The selected design direction: modern, playful local AI tools, represented by four faceless ingredients on one shared pick. Character comes from the shapes and their movement. This is the single maintained design prototype; the earlier visual comparisons have been removed.

The direction is now applied to the native Dictado app. See [native implementation and verification](IMPLEMENTATION.md) for what is connected to real capture and what still needs device testing. Acta remains a concept for its next iteration.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --directory design/tapas
```

Open [the prototype](http://localhost:8765/). No build step, dependencies or external assets are needed.

Explore [Dictado form and motion](dictado-motion.html): three smaller Gráfico signals—La miga (188 × 40 px pill), El pintxo (82 × 78 px floating mark), and El borde (124 × 28 px edge tab). El pintxo is the new leading exploration. Click the signal to start or finish; hover or focus for secondary controls. Optional live words appear in a separate two-line caption. Delivery, recovery and reduced motion are interactive. These are HTML concepts; native presentation has not changed.

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
- [dictado-motion.html](dictado-motion.html), [dictado-motion.css](dictado-motion.css), [dictado-motion.js](dictado-motion.js): focused popup placement and motion study.
- [IMPLEMENTATION.md](IMPLEMENTATION.md): native Dictado implementation and verification.
- [BEHAVIORS.md](BEHAVIORS.md): flow decisions, recovery behavior and native implementation boundaries.

In the browser prototype, speech, permissions, model preparation, app audio, capture and file search are simulated. Sample data and preferences stay in memory until reload. Explicit export buttons download sample Markdown; copy buttons use the browser clipboard. Nothing records audio or reads your folders.

Dictado is the first product. Acta is next; Captura and Consulta are later concepts, labeled accordingly throughout the preview.
