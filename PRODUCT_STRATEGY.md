# Tapas · Product and identity strategy

Small tools. Good company.

**Capture on your Mac. Keep your files. Build whatever comes next.**

## Your files are the interface

Tapas captures useful material into local, human-readable files that belong to
the user. The app is a convenient way to capture and browse that material; it
must not become the only way to access it.

Transcripts should be legible to a person, a text editor, a script, and any coding
agent. People can use an existing agent, build their own harness, or assemble a
workflow Tapas has never anticipated. Useful timestamps and language metadata
belong beside the text in an open format. Reading the data must not require a
Tapas service, API, special export operation, or proprietary database.

Files come first; integrations are optional conveniences. An MCP server may
eventually make access easier, but it must never be required to read or use a
saved transcript. A person should be able to find, copy, move and work with the
files independently of the app. Agents and scripts should have the same direct
path, subject to the access the user grants them.

The user decides which agents can access the files and where subsequent analysis
runs. Local capture does not imply that a separately chosen cloud agent runs
locally. Tapas should never silently send the user's transcripts to one.

Future summaries, meeting insights, skills and MCP integrations are conveniences
built on those files. Derived results should preserve the source transcript;
they should not replace it or trap it inside the app.

[Product messaging](design/tapas/MESSAGING.md) records the approved wording and
how to demonstrate this principle without promising unimplemented behavior.

## First release: two complete tools

Tapas launches when **Dictado and Acta are both ready**. The first installable artifact, **0.1.0 Preview 1**, is a Dictado prerelease for testing. It does not replace the two-tool launch: Acta is visibly marked In dev, and preview notes identify what is unfinished.

| Tool | The job | Presence |
| --- | --- | --- |
| Dictado | Speak a thought and put the words into the app in front of you. | El borde: a small recording signal, hidden while idle. |
| Acta | Stay in a conversation and keep a useful local transcript. | A persistent meeting companion; the floating pintxo is the current visual exploration. |

Both belong in the launch product menu. Development previews must identify unfinished functionality honestly; the full release should offer two functioning tools. Captura and Consulta remain uncommitted ideas. They have no launch cards, locked slots, release dates, or promised sequence.

The first release needs dependable recording, clear start/stop state, appropriate permissions, retained results when delivery fails, and useful local files. Acta still needs its native implementation and its complete meeting experience. A finished visual concept does not make a tool ready to release.

## The mark is independent of the catalog

The pintxo always has four ingredients on one pick. They express variety held together by Tapas. **They do not count products**, represent four roadmap slots, or map to named tools.

Saffron, cobalt, paprika and olive form one shared palette. A tool can have a favored accent, but it does not own a color. Dictado's voice signal deliberately uses all four. New tools may reuse accents; their names and distinct glyphs provide identity. State must always have a readable label, never only a color.

Adding a fifth tool adds one product entry and its glyph. The app icon, pintxo, palette and four-piece waveform stay intact.

## One family, different amounts of presence

Every tool shares typography, materials, icon treatment, state labels, recovery conventions and the assemble → active → gather → settle motion language.

Dictado is brief and peripheral: start recording on the shortcut, show a small signal, optionally show live words, then disappear after delivery. El borde transforms the same four ingredients into voice bars. It must clear the menu bar and camera notch.

Acta lasts longer: its companion must communicate recording, paused state, elapsed time and source problems. The floating pintxo is a visual starting point. These meeting controls and behaviors still need to be designed together; a larger mascot alone is not the experience.

## Growing the plate

Keep a simple list of available tools, with a name, a distinct glyph and a clear action for each. Do not design a fixed four-slot grid or use the logo as product navigation. Add grouping or favorites only when the available tools make it useful.

A new idea earns a separate tool when it solves a recurring job, has a clear start and useful result, and can be made dependable. Small variations can remain settings or features inside an existing tool. Roadmap experiments stay out of the customer-facing catalog until there is a real commitment to ship them.

## Source of truth

This document records launch scope and how the identity scales. [Design behaviors](design/tapas/BEHAVIORS.md) record interaction decisions. [Implementation status](design/tapas/IMPLEMENTATION.md) distinguishes native behavior from HTML concepts. Internal research and uncommitted ideas remain in the private backlog.
