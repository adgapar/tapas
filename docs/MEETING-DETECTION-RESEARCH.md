# Meeting detection comparison

Checked September 16, 2026 against the vendors' own documentation.

| Product | Documented detection | Calendar role |
| --- | --- | --- |
| [Notion](https://www.notion.com/en-gb/help/ai-meeting-notes) | Its FAQ says the desktop app observes processes actively using the microphone, without listening to their audio for detection. | Calendar integration supplies meeting entry points and context. Its [notification settings](https://www.notion.com/help/notification-settings) describe audio activity plus a matching calendar event. These pages do not establish that a calendar is required for every detection path. |
| [Granola](https://docs.granola.ai/help-center/taking-notes/notifications) | Detects microphone use for unscheduled calls and identifies the app in its prompt. | Reminds one minute before events with at least two attendees; associates detected calls with events within its documented 15-minute window after the scheduled meeting. |
| [Circleback](https://support.circleback.ai/en/articles/10460578-record-meetings-with-the-desktop-app) | Desktop detection notices an app starting to use the microphone. Optional automatic start/end use detection and microphone inactivity. | Calendar joining preferences control its bot workflow; desktop recording can work without a bot. |

These are documented behaviors, not evidence of their internal macOS APIs or
process-attribution algorithms.

## Implications for Acta

Microphone activity is a sound base for cross-platform detection. A separate
integration for every meeting website is unnecessary for this behavior. The Arc
failure came from mismatched capitalization between its helper and host bundle
IDs, not a missing Google Meet integration; matching now normalizes casing.

Optional calendar reminders would add a useful independent signal, including
before microphone activity, plus meeting titles and attendees. They should
coexist with unscheduled-call detection and deduplicate prompts for the same
conversation. Calendar integration is not implemented by this change.

Further reliability work should validate attribution across helper architectures,
device changes, mute/reconnect, and app restarts. Unknown microphone owners should
remain diagnosable rather than be guessed from the foreground app. Microphone use
alone cannot prove that a meeting is happening or identify the active browser tab.
