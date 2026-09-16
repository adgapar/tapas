# Use Tapas with your AI assistant

On the final onboarding step, or in **Preferences → Use with your AI assistant**,
choose Claude Code, Codex, or Cursor, and select **Install skill**.
Start a new assistant session, then ask
something like: “Find what we decided about onboarding last week in my Tapas recordings.”
Assistant setup is optional and does not require a practice take. Installation
happens on the same page. Preferences also lets you update or remove an intact Tapas skill,
and copy a setup command for the locally installed app. The command does not
fetch a script or require another package manager.

The skill gives your assistant a search-and-citation workflow. It does not grant
filesystem access or connect a cloud assistant to your Mac. Your assistant may
process the text it reads through its own provider. Removing the skill does not
remove recordings.

## Templates and playbooks

Installing or updating the skill from Tapas (including the setup command) adds
starter Markdown files to `templates/` and `playbooks/` in your current transcript
folder. **Preferences → Use with your AI assistant → Open templates** also adds
missing starters and opens the templates folder in Finder. Existing files are
never overwritten, including customized starters. Deleted starters are restored
when you next install/update the skill or use Open templates.

Templates describe the desired document. Playbooks explain how to produce it.
Both are ordinary Markdown: use a title, headings, and brief instructions for each
section. No JSON schema, registration, or required frontmatter is involved. Add
or edit a `.md` file yourself, or ask your assistant to customize it. Your assistant
reads the selected files when running a task; library edits need no skill reinstall.
Update an older installed skill once to teach it this workflow.

Starters include meeting notes, customer interviews, and project updates, with
playbooks for meeting notes, weekly reviews, polishing saved dictation, and
learning useful workflows from your history. Try:

- “Use Tapas to make notes from yesterday's meeting with the meeting-notes template.”
- “Use my customer-interview template for this recording.”
- “Create a retrospective template in my Tapas templates folder.”
- “Review this week's recordings and save a project update.”

The default Acta meeting-notes template puts **Action items** directly after the
summary, grouped into **You** and **Others**. Other participants can remain a
single group. Agreed tasks with uncertain ownership appear under **Unclear owner**.
Each item has a source citation and a deadline when one was stated. Capture-source
labels alone do not establish ownership. For long meetings, the playbook reviews
the full recording and reconciles repeated, changed, or cancelled actions.

Additional playbooks work across recordings:

| Ask your assistant | Result |
| --- | --- |
| “Find my recurring requests in last month's Dictado history.” | Evidence-backed candidates for templates, skills, and routines |
| “Learn my writing preferences from my dictations.” | An editable guide separating explicit preferences from tentative patterns |
| “Develop my onboarding idea from my saved recordings.” | A sourced brief with alternatives and unanswered questions |
| “Review my commitments from the last month.” | Tasks, supported owners, deadlines, and known or unknown status |
| “Prepare me for a follow-up conversation about onboarding.” | Relevant history, decisions, open questions, and a suggested agenda |
| “Suggest improvements to my templates from repeated dictation instructions.” | Proposed changes with supporting examples; edits only when requested |

Personal-learning playbooks use the last 30 days unless you specify a period and
report how much saved history they reviewed. Dictado history must have been enabled
to supply saved takes; they cannot recover unsaved dictations or redacted values.
Spoken input does not show final writing, whether an assistant helped, or whether
a task was completed. Findings remain suggestions unless you ask to apply them.
You can also explicitly ask for a proposed template or playbook to be created in
your library. A proposed routine does not enable background execution.

Results appear in the assistant conversation unless you ask to save them. Saved
results default to separate Markdown files under `outputs/`, with source citations.
Original recordings are preserved. All local assistants use the current library's
same templates. Changing the transcript folder does not move custom templates;
copy them to the new folder if you want to keep using them there.

This release supplies instructions and starter files. Tapas does not launch an
agent, schedule playbooks, or automatically generate notes. Removing the skill
leaves your templates, playbooks, and outputs in place.

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
