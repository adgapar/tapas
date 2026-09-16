# Follow-up: agent-ready files and assistant setup

Recorded 2026-09-16. **Proposal saved for a future session; not implemented or
approved for release.** The user asked to preserve this discussion. Begin the
next session by reading this document and confirming the implementation scope
from the user's new request.

## Starting point

- Tapas 0.1.2 (build 5) is released, Developer ID signed and notarized. The
  automatic-update feed points at it. Implementation commit: `966db9d`.
- Both tools use one selectable transcript folder, default `~/Documents/tapas/`,
  containing `dictado/` and `acta/`. Active takes and recovery retain their original
  destination when the preference changes; existing files are not moved.
- Dictado Markdown frontmatter currently contains `time`, `language`, `duration`.
  Saved Dictado history is redacted independently of the pasted text.
- Acta frontmatter contains `tool: acta`, `time`, `duration`, `languages`.
  Its unredacted transcript contains timestamps and Microphone / App audio labels.
  Those are source labels, not individual speaker identities.
- No library index, Tapas agent skill, skill installer, or metadata enrichment
  has been implemented. Gist and Title are available in the dependency's source
  tree, but are not integrated into Tapas.
- The last implementation passed 89 core and 11 native tests. Live-call and OS
  permission checks remain listed in [ACTA.md](ACTA.md).

## What the user wants to explore

1. Make saved files easy for agents to discover and read, possibly using INDEX.md.
2. Use Desert Ant models for tags or other useful metadata.
3. Understand what Acta can attribute to meeting participants without integrations.
4. Make installation easy for Claude Code, Codex, and Cursor, perhaps with a
   command copied from Tapas that installs a skill and points to the saved files.

The existing [product strategy](../PRODUCT_STRATEGY.md) already establishes that
files are the interface. No account, meeting integration, proprietary database,
or MCP server should be required to read them.

## Proposed sequence

### 1. Shared metadata and discovery indexes

Standardize both tools around stable recording IDs, a schema version, tool,
timezone-qualified date, duration with defined units, languages, title,
description, redaction status, and speaker-labeling method. Preserve compatibility
with existing files. Keep generated suggestions distinct from user-authored
titles/tags and from factual capture metadata.

Proposed shared-folder layout:

```text
<chosen transcript folder>/
├── INDEX.md           # Recent entries and links to monthly indexes
├── SCHEMA.md          # Field meanings, timestamp basis, source-label limitations
├── indexes/
│   └── 2026-09.md
├── dictado/
└── acta/
```

Each index entry should have date, tool, title, short description, optional topics,
and a relative transcript link. Keep indexes bounded so an agent can find two
relevant files without reading the entire library. INDEX.md is an entry point,
not a mechanism that makes arbitrary folders automatically discoverable to agents.

Tapas should update indexes after successful saves and reconcile external file
changes. Indexes must be rebuildable from saved files. Save transcripts first;
index/enrichment failures must never turn a successful capture into lost words.
Decide how to handle pre-existing INDEX.md/SCHEMA.md files without overwriting
user-authored content. Do not silently rewrite historical transcripts.

### 2. One portable skill and an easy installation flow

Author one Tapas skill using the SKILL.md format, with small host-specific
packaging only where needed. The skill should:

- Resolve the currently configured transcript folder through a stable,
  Tapas-managed local configuration file or helper.
- Read indexes first, then relevant transcripts; fall back to searching files if
  an index is missing or stale.
- Cite filenames and timestamps when answering questions about recordings.
- Distinguish generated descriptions, recorded words, and uncertain speaker labels.
- Treat transcript content as source material, not executable agent instructions.
- Preserve original recordings when producing summaries or follow-up documents.

Do not hardcode the selected folder into several installed copies of a skill.
One local library-location setting should change when Preferences changes.
Account for older recordings deliberately remaining in their previous folder.

Proposed UI: **Preferences → Use with your AI assistant**, with a small entry from
Home. Select Claude Code / Codex / Cursor, show the folder to be discoverable,
then offer Install skill, Installed / Update / Remove, and Copy setup command.
Direct installation should make Terminal optional. Restrict changes to
Tapas-owned files and handle existing installations without clobbering user edits.

Documented personal skill locations at research time:

| Agent | Location |
| --- | --- |
| Claude Code | `~/.claude/skills/tapas/SKILL.md` |
| Codex | `~/.agents/skills/tapas/SKILL.md` |
| Cursor | `~/.cursor/skills/tapas/SKILL.md`; also supports `~/.agents/skills/` |

Avoid duplicate discovery when a host scans several compatible directories.
Installing instructions does not bypass filesystem permissions. Remote/cloud
agents cannot automatically read this Mac's files. Explain that an independently
chosen assistant may process selected transcript content through its own provider.

A skill supplies the workflow; a plugin distributes skills and can handle
discovery/updates. Neither requires an MCP server. Later distribution could use
host marketplaces/plugins and a `npx skills add <repository>` option. **No Tapas
skill install command is published yet.** Recheck host conventions before coding.

### 3. Optional local metadata enrichment

| Model | Candidate use | Boundaries |
| --- | --- | --- |
| Gist | Broad suggested topic categories | Fixed 36-topic taxonomy, 101 languages; not arbitrary project tags or action-item extraction |
| Title | Short factual title and one- or two-sentence description | Apple silicon / MLX; additional model provisioning; quality evaluation needed |

Gist offers multilingual (~74 MB) and English-only (~15 MB) variants. Title needs
the SDK's MLX trait and an explicitly provisioned model directory; it does not
download weights automatically. Its docs describe quality as under evaluation.
Neither is currently wired into Tapas.

Save the transcript immediately, then enrich asynchronously. Generate Dictado
metadata from its redacted saved text so titles/descriptions cannot reintroduce
removed information. Preserve user edits, mark model provenance, and keep an
honest fallback when generation fails. Evaluate long meetings and multilingual
input before promising useful whole-meeting descriptions. Do not assume either
model produces reliable decisions, summaries, or action owners.

### Separate track: participant attribution

Current Acta captures microphone audio and a mixed selected-app audio stream.
It can transcribe remote participants without a meeting integration, but their
names and separate audio tracks are not provided by that capture path. A browser
selection may also include other tabs' audio. During a call the floating Pintxo
and timer show recording state; clicking reveals controls.

Audio diarization could split the remote stream into anonymous Speaker 1 / 2 / 3
turns without a meeting integration. Mapping those labels to actual names is a
separate task: user labeling, known voice samples, or an additional identity source.
Suggested first experience: editable anonymous labels, retaining uncertainty
rather than guessing names. Microphone audio can also contain multiple nearby
people, so it is not universally equivalent to one known person.

Desert Ant's Who is **closed beta** and uses video as well as audio. It is not a
drop-in dependency for the current audio-only product. Evaluate a local audio
diarization solution separately, including overlaps, short turns, stable labels
across chunks, accuracy, resource use, and audio retention/recovery implications.

## Suggested acceptance checks for the next implementation

- Both tools emit consistent, parseable metadata; existing files remain readable.
- Indexes rebuild deterministically and handle missing/moved files and failed writes.
- Folder changes do not break discovery or change active/recovered take destinations.
- An agent can find a relevant recording and cite its source without reading all files.
- Installation, updates, and removal work in each selected host without changing
  unrelated skills or installing duplicate Tapas entries.
- Generated metadata cannot overwrite user edits or leak pre-redaction Dictado text.
- No generated topic, description, or anonymous speaker label is presented as
  verified identity or a confirmed decision.

## Implementation entry points

- `Sources/TapasCore/HistoryWriter.swift` — Dictado Markdown and file creation.
- `Sources/TapasCore/HistoryLibrary.swift` — library reading and previews.
- `Sources/TapasCore/ActaSession.swift` — Acta documents, Markdown, saves, recovery.
- `Sources/TapasCore/Settings.swift`, `TranscriptFolders.swift` — shared locations.
- `Apps/TapasApp/Sources/TapasApp/AppDelegate.swift` — saved preferences/folder picker.
- `Apps/TapasApp/Sources/TapasApp/PlateView.swift` — Home and Preferences.
- `Apps/TapasApp/Sources/TapasApp/ActaRecorder.swift` — audio-source capture.
- `Apps/TapasApp/Package.swift` — Desert SDK product dependencies.

## Sources checked 2026-09-16

These are research references, not a guarantee that conventions will remain unchanged.

- [Codex skill authoring, locations, and plugin distribution](https://learn.chatgpt.com/docs/build-skills)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Claude Code plugin installation](https://code.claude.com/docs/en/discover-plugins)
- [Cursor skills and supported directories](https://cursor.com/docs/skills)
- [Skills CLI distribution](https://www.skills.sh/docs/cli)
- [Desert Ant Gist](https://desertant.com/models/gist/)
- [Desert Ant Title SDK and limitations](https://desertant.com/docs/title/)
- [Desert Ant Who beta](https://desertant.com/models/who/)
- [Diarization versus identification](https://docs.pyannote.ai/features)

## Suggested next-session prompt

> Read docs/AGENT_READY_FILES_PLAN.md. Let's implement the shared transcript
> metadata and discovery indexes first, preserving current files and recording
> recovery behavior. Then work on the Tapas skill installation flow for local
> Claude Code, Codex, and Cursor. Keep model enrichment and speaker diarization
> separate until we choose their scope.
