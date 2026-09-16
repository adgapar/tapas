# Tapas · Pintxo / Gráfico

**Small tools. Good company.**

Tapas’s main brand line pairs the usefulness of small AI tools with the warmth of sharing tapas. Use this wording consistently; uppercase and a line break between the sentences are welcome in visual layouts.

The product promise is **“Capture on your Mac. Keep your files. Build whatever comes next.”**
The guiding principle is **“Your files are the interface.”** People can use a
coding agent, write scripts, or build their own agent harness around readable
local files. Files come first; integrations are optional conveniences. See
[approved product messaging](MESSAGING.md) for the landing-page copy and demonstration.

The selected design direction: modern, playful local AI tools, represented by four faceless ingredients on one shared pick. The four ingredients belong to the brand, not to individual products; their count stays fixed as the catalog grows. Character comes from the shapes and their movement. This is the single maintained design prototype; the earlier visual comparisons have been removed.

The direction is now applied to the native Dictado app. See [native implementation and verification](IMPLEMENTATION.md) for what is connected to real capture and what still needs device testing. Acta also has a native implementation; see [capture, recovery and remaining verification](../../docs/ACTA.md).

## Current interaction review

Start with [One home, small tools](interactions.html), the current clickable
interaction study. It covers shared tool navigation, automatic meeting
suggestions, contextual permissions, capture, recovery, Recent, shortcuts and
transcript folders. [Interaction decisions and review paths](INTERACTIONS.md)
record the intended behavior and remaining native verification. The older study
below remains a visual reference. The reviewed flows are now implemented natively;
see the verification section for the remaining live-device checks.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --directory design/tapas
```

Open [the prototype](http://localhost:8765/). No build step, dependencies or external assets are needed.

Explore [Dictado form and motion](dictado-motion.html): **El borde is the selected Dictado direction**, a 124 × 28 px top-edge signal. Its four pintxo ingredients rotate and spread into voice bars during capture, then gather back into the mark. The enlarged motion view shows the same four elements transforming. The floating Pintxo is implemented as Acta’s audio-reactive companion. Idle is hidden; starting a take reveals the signal immediately. A camera-notch toggle previews its position below the camera and menu bar. Live words are optional and separate from recording status. El borde is also implemented natively in SwiftUI/AppKit, with actual microphone levels, display-safe positioning, separate live captions and a brief delivery receipt. The camera toggle remains an HTML exploration.

Use the journey rail to explore onboarding, Dictado, Acta and Your plate. The scenario picker introduces permission, connection, paste and save failures. Start an Acta session and switch to another journey to explore its persistent status. Reset demo or reload to start over.

## Selected visual language

| Element | Treatment |
| --- | --- |
| Identity | Four distinct pieces, one tilted pick, no face |
| Ingredients | Saffron `#f0c740`, cobalt `#3355c6`, paprika `#e65f3b`, olive `#81934f` |
| Outlines | Ink `#303b2b`, precise offset shadows |
| Surfaces | Warm paper, restrained borders, generous space |
| Typography | Direct sans-serif headings with occasional italic serif accents |
| Personality | Brief, purposeful motion; warm copy with a little Spanish flavor |

The pintxo assembles during setup, transforms into four voice bars arranged horizontally for Dictado, gathers while working and settles when output arrives. Its saffron, cobalt, paprika and olive ingredients keep their identities through every transformation. Status also has a text label, so motion and color are never the only signal. Reduced-motion preferences are respected.

## Files

- [index.html](index.html): prototype shell and journey navigation.
- [style.css](style.css): Gráfico design, motion and responsive layouts.
- [app.js](app.js): connected interactions and sample content.
- [icon.svg](icon.svg): selected faceless pintxo mark.
- [dictado-motion.html](dictado-motion.html), [dictado-motion.css](dictado-motion.css), [dictado-motion.js](dictado-motion.js): focused popup placement and motion study.
- [IMPLEMENTATION.md](IMPLEMENTATION.md): native Dictado implementation and verification.
- [BEHAVIORS.md](BEHAVIORS.md): flow decisions, recovery behavior and native implementation boundaries.
- [MESSAGING.md](MESSAGING.md): approved product promise, supporting copy and files-first principle.

In the browser prototype, speech, permissions, model preparation, app audio, capture and file search are simulated. Sample data and preferences stay in memory until reload. Explicit export buttons download sample Markdown; copy buttons use the browser clipboard. Nothing records audio or reads your folders.

The first public release includes Dictado and Acta. The HTML Acta journey is a design preview; its native implementation is under device verification. Other ideas are kept out of the product catalog; see the [product and identity strategy](../../PRODUCT_STRATEGY.md).
