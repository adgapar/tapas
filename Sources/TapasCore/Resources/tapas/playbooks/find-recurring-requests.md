# Find my recurring requests

Use when asked to learn what the user repeatedly requests in Dictado and suggest
reusable templates, skills, or routines.

## Review the evidence
Use the requested period, or the last 30 days if unspecified; state the actual
dates. Read saved Dictado takes, deduplicating recording IDs. Report the number
reviewed, date coverage, and any sampling or inaccessible history. History may
be disabled or sparse; absence of saved takes is not absence of a habit.
Group by intent rather than repeated vocabulary. Distinguish actual requests
from quoted requests, examples, and general spoken notes. Support a recurring
pattern with multiple distinct takes; label single examples as tentative ideas.
Count matching takes, not how many times a phrase occurs in one take.

## Produce useful suggestions
For each strong pattern, give a plain-language name, matching-take count within
the reviewed set, representative source citations, and the repeated work involved.
Suggest whether a document template, reusable skill, or routine would help, with
an example invocation and the variable inputs it would need. Prioritize a few
useful candidates rather than inventing a pattern for every take.
Dictations do not establish what the assistant answered, whether it helped, or
whether the user completed the work. Do not claim measured time savings.

Return findings and proposals in the conversation. If asked to save, use a new
Markdown file under `outputs/`. When creation is already requested, create the
requested library template or playbook within that scope; otherwise propose it
first. Draft proposed agent skills under `outputs/` unless a host installation
was requested. A suggested routine remains a proposal, not an enabled automation.
