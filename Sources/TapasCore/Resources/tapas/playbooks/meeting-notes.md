# Generate meeting notes

Use when asked to turn a meeting into notes, including customer interview notes.
Read the requested recording and the selected template under `templates/` in
this library. Default to `meeting-notes.md` for a general recap and
`customer-interview.md` for customer research, unless the user chooses otherwise.

Follow the template's section guidance, keeping claims tied to transcript
filenames and Acta offsets. Audio-source labels do not identify individual people.
Preserve uncertainty, and do not turn proposals into decisions.

For the default meeting-notes template, put action items immediately after the
summary, grouped into You and Others, with Unclear owner only when needed.
Extract concrete agreed work across the entire meeting, not only its closing
minutes. For long recordings, review successive sections and reconcile the
candidate actions against later passages before producing the final list.
Merge repeated mentions of the same task, incorporate changed deadlines, and
exclude tasks explicitly cancelled or already completed in the meeting. Preserve
distinct deliverables. Cite the passage establishing each action, plus a later
change when necessary.

Ownership follows who accepted or was assigned the task, not who mentioned it.
Microphone, App audio, and Computer audio are capture sources, not reliable user
or participant identities. Use them with established speaker context, never as
the sole basis for assigning a task to You or Others. Keep other participants
as a group; do not require diarization or invent names. If ownership is unclear,
say so without blocking the rest of the notes.

Capture deadlines as stated; resolve relative dates only when the recording date
and context support it. Keep tentative suggestions and unanswered requests out
of agreed action items. Generating notes does not create external tasks or send
reminders. Honor a selected custom template's structure instead of imposing these
headings on every kind of meeting document.

Return the document in the conversation unless asked to save it. When saving
without a specified destination, use a descriptive new Markdown filename under
`outputs/` in the current library. Link to source files relative to the output.
Preserve existing outputs unless the user asks to revise them.
