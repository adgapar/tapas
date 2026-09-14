# Gráfico · Product behaviors

This document records the selected interaction design alongside the [interactive prototype](index.html). These are design decisions and proposed future behaviors, not claims that the native app implements every flow.

## One shared home

Tapas is a collection of small tools that produce useful results where the user already works. The pintxo joins them into one identity. Each tool has a simple glyph and a recognizable ingredient color: Dictado saffron, Acta cobalt, Captura paprika, Consulta olive.

The menu-bar home, “Your plate,” contains Tools, Recent and Preferences. Dictado is the first available tool. Acta is marked Next; Captura and Consulta are marked Later. In this design preview their cards open interactive concepts. Native release builds should distinguish shipped tools from previews just as clearly.

The sample desktop has a notch status and an alternate notchless presentation. Clicking the status opens Your plate. A running Acta session also has a compact companion with an Open action.

## First taste: onboarding

| Step | User action | Result and recovery |
| --- | --- | --- |
| Meet Tapas | Start setup | Introduce the collection through one useful task: Dictado. |
| Microphone | Allow access | Explain that speech capture begins with a take. A denied state points to microphone settings. |
| Paste | Enable Accessibility, or defer | Explain its role in shortcuts and pasting. Deferred permission keeps a manual text handoff available. |
| Prepare | Wait for local voice models | Show download/preparation progress. An interrupted download retains sample progress and offers retry. |
| Try it | Choose shortcut, start and finish a sample take | Show words arriving; allow cancellation. Continue becomes available after a completed thought. |
| Ready | Try Dictado or open Your plate | Reinforce the shortcut and the Markdown destination. |

The pintxo assembles as preparation advances. Permission requests arrive with the action they enable. Onboarding never asks for Acta app audio or Captura screen access.

The preview supports Control–Option and Right Command shortcuts while its page is focused. Buttons provide the same actions. Native shortcut registration and Accessibility requirements must be handled by the app; browser keyboard behavior is only illustrative.

Leaving setup returns to Your plate. Continue setup resumes at microphone access, model preparation or the practice step, depending on what is ready. Designer navigation allows independent previews with microphone and models initially ready; explicitly beginning onboarding clears those simulated prerequisites.

## Dictado: press, speak, press

| State | Visible behavior | Next action |
| --- | --- | --- |
| Ready | Quiet assembled pintxo, shortcut hint | Start a take. |
| Listening | Pieces separate, labeled status, optional live words | Same shortcut finishes; Escape cancels. |
| Finishing | Working motion and explicit label | Prevent another take until completion. |
| Delivered | Text lands in the sample note; pieces settle | Return to work. Save a Markdown history entry if enabled. |
| Paste unavailable | Keep recognized text visible | Place it in the sample note using the fallback action. Native implementation should offer copy/retry. |
| No speech | Explain that nothing was saved | Retry or start another take. |
| Microphone unavailable | Explain the missing permission | Recover access, then begin a take. |
| Models unavailable | Explain the prerequisite | Continue setup. |

The overlay preference controls live words; the status remains visible when the overlay is off. A canceled take creates no history entry. The sample Notes editor retains its contents across journey navigation.

When Acta is recording, the Dictado button explicitly says “Pause Acta & talk.” Starting the take pauses Acta. The meeting remains paused after dictation until the user resumes it. This is the proposed microphone ownership policy and needs corresponding native audio coordination.

Prototype limitation: switching journeys cancels a Dictado take and its pending completion timer. A production implementation should define and test how closing an overlay differs from canceling capture, and retain completed text through UI changes.

## Acta: stay for the conversation

Acta captures a meeting through the microphone and one chosen app, without joining as a bot. This preview uses Meet, Zoom and Teams as sample choices. It does not connect to those apps.

| State | Behavior |
| --- | --- |
| Preflight | Choose the meeting app. Show microphone and app-audio prerequisites before enabling Start. |
| Recording | Display elapsed active time, both source indicators and a sample live transcript. |
| Paused | Stop the active timer and transcript updates. Resume is explicit. |
| Collapsed | Keep a compact status card; recording continues when navigating to other journeys. |
| App audio interrupted | Identify the missing app source; microphone capture continues. Offer reconnect. |
| Finishing | Keep completion work running even if the user changes journeys. |
| Saved | Show a transcript receipt with open/export actions and an entry in Recent. |
| Save failed | Retain the transcript in memory. Offer retry and an immediate Markdown export. Retry must not duplicate the history entry. |

The timer represents recorded time, excluding pauses. The preview transcript is scripted and source indicators are illustrative. It makes no speaker attribution, diarization, summary or action-item promises. The saved sample includes timestamps. Finishing before speech arrives yields an explicit no-speech note; native implementation should decide whether to offer discard for an empty session.

The companion and notch communicate ongoing capture. Collapsing a window never implies stopping the meeting. A save failure remains recoverable from the Acta journey after navigating away. Production recovery needs durable temporary storage: browser memory does not survive reload or a crash.

## Files and preferences

The intended output root is `~/Documents/tapas/`, with tool-specific folders such as `dictado/` and `acta/`. Plain files are usable by the person and their other tools.

Recent filters the sample library by title, content and tool. Open shows readable content, its intended destination, Copy text and Export .md. Export generates a real browser download labeled as prototype sample content. The preview does not write into the displayed native folder.

Preferences expose the dictation shortcut, live-word overlay, history saving and simulated paste access. Native Accessibility access belongs to macOS; the prototype toggle exists to explore both states. Preferences and history reset on reload. Clipboard failures direct the user to export.

## Captura: later concept

The journey starts from a suggested spoken request, then confirms the selected window before capture. Screen access is requested here. The proposed output pairs an image with a readable text sidecar so both people and tools can find and reuse the moment.

The preview simulates capture, permission denial/recovery, a completion receipt and opening the sidecar. Export contains only a sample Markdown note. No PNG is generated and no real OCR or screen capture occurs. The native flow still needs the actual window picker, capture pipeline and sidecar extraction.

## Consulta: later concept

The user chooses folders, enters remembered words, reviews paths and snippets, and opens a match. Empty queries and zero selected folders prompt a correction. No matches suggest changing terms or scope.

The prototype searches a few fictional text files by all entered words within title/content and selected scope. It does not access the disk or Spotlight. The native concept should perform scoped name/content search and show understandable evidence for each result.

## Motion, access and implementation boundaries

- Ready is quiet. Listening, working and completion have distinct, brief shape behaviors.
- Keep status labels, visible keyboard focus, meaningful button names and reduced-motion alternatives.
- The responsive browser layout supports reviewing the design on small screens; Tapas remains a macOS product.
- Error messages identify what failed, what was retained and the next useful action.
- The journey rail, failure scenarios and simulated desktop belong to the design viewer, not the product UI.
- Native adoption must connect these surfaces to real permissions, audio state, model progress, persistence, focus restoration and file handling. The HTML does not replace those systems.

## Validation

The connected browser flows were exercised in isolated Chrome: complete onboarding with denial and download retry; Dictado fallback, silence and cancellation; Acta persistence, pause/resume, source interruption, failed save, export and retry; history filtering and preferences; Captura sidecar; Consulta matches and empty results. All six journeys were checked at 390 px for horizontal overflow and clipped controls. The notchless toggle and browser runtime errors were also checked. Native Swift behavior is outside this prototype validation.
