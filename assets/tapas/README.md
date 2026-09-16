# Tapas artwork

The approved artwork comes from the native `PintxoMark` in
`Apps/TapasApp/Sources/TapasApp/Grafico.swift`. These exports use the released
0.1.3 app icon. The SVG embeds the same PNG rather than redrawing the mark.

Regenerate from an approved packaged app:

```sh
python3 Scripts/export-brand-assets.py --app dist/0.1.3/Tapas.app
```

Keep the app icon, onboarding mark and documentation artwork consistent.
