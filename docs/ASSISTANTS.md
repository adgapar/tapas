# Use Tapas with your AI assistant

After your onboarding practice take, choose **Set up assistant**, or open
**Preferences → Use with your AI assistant** anytime. Choose Claude Code, Codex,
or Cursor, and select **Install skill**. Start a new assistant session, then ask
something like: “Find what we decided about onboarding last week in my Tapas recordings.”
The same controls show installation status, update or remove an intact Tapas skill,
and copy a setup command for the locally installed app. The command does not
fetch a script or require another package manager.

The skill gives your assistant a search-and-citation workflow. It does not grant
filesystem access or connect a cloud assistant to your Mac. Your assistant may
process the text it reads through its own provider. Removing the skill does not
remove recordings.

## Files and discovery

New Dictado and Acta files contain shared factual YAML metadata. Dictado keeps
its redacted saved text; Acta retains the full transcript and source timestamps.
Existing transcripts are never migrated or rewritten during indexing.

The transcript folder contains:

- `INDEX.md`: the latest 50 recordings and links to monthly archives.
- `SCHEMA.md`: metadata, timestamp, redaction, and audio-source definitions.
- `indexes/YYYY-MM.md`: up to 200 recordings per page, followed by numbered pages.
- `dictado/` and `acta/`: the original Markdown transcripts.

Entries contain dates, tools, durations, optional user titles, relative links,
and excerpts labeled as previews. There are no generated topics or summaries.
Missing dates are grouped under `unknown-date`. New timestamps use UTC (`Z`);
older offset-qualified timestamps retain their original month grouping.

Tapas rebuilds indexes after saves, when Home opens, and about once a minute
while running. **Rebuild recording indexes** provides a manual refresh. A failure
leaves the saved transcript intact and appears in Preferences. Search source files
if indexes are missing or stale; a preview does not cover an entire meeting.

Tapas only replaces generated pages whose ownership checksums still match. It
leaves existing user pages and edited generated pages untouched. Move a conflicting
page aside to resume generation. Keep assistant-authored project indexes, summaries,
and future automation outputs in separate files outside `indexes/`.

Optional transcript `title` values are used in indexes. Use a single-line YAML
scalar; quote titles containing punctuation using JSON double quotes or YAML single
quotes. Other user fields, including `tags`, remain untouched. Indexing reads the
Tapas metadata subset, not arbitrary YAML features such as multiline titles.

## One location setting

`~/Library/Application Support/Tapas/library.json` records `current_root` and
`previous_roots`. Tapas updates it as the transcript preference changes. The skill
reads this file each time instead of embedding paths into installed copies.
Previously selected folders remain searchable; files are not moved. Active and
recovered recordings keep their original destinations.

## Installation ownership and host compatibility

Tapas installs a personal skill named `tapas` for each selected assistant, with an ownership receipt:

- Claude Code: `~/.claude/skills/tapas/`.
- Codex: `~/.agents/skills/tapas/`.
- Cursor: reuses an existing compatible Tapas installation; otherwise uses
  `~/.agents/skills/tapas/`, shared with Codex.

Claude Code and Codex can be installed, updated, and removed independently.
Cursor reuses the first existing Tapas folder in this order: `.agents`, `.claude`,
`.cursor`, `.codex`; if none exists, it installs into `.agents`. It does not add
another copy solely for Cursor. Because Cursor also discovers other assistants’
folders, multiple installed copies may be visible there; this does not block
installation or management for any assistant. Project-level and marketplace
copies are outside this installer's scope.

Updates and removal refuse modified, unowned, or linked skill files. Additional
files in a skill directory are preserved. Removing a shared installation affects
all assistants discovering it. Existing custom skills are never adopted silently.

Host conventions checked against [Codex documentation](https://learn.chatgpt.com/docs/build-skills),
[Claude Code documentation](https://code.claude.com/docs/en/skills), and
[Cursor documentation](https://cursor.com/docs/skills).
