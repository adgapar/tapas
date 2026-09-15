# Gráfico · Product behaviors

This document records the selected interaction design alongside the [interactive prototype](index.html). These are design decisions and proposed future behaviors, not claims that the native app implements every flow.

Dictado now has a native implementation of this direction. [IMPLEMENTATION.md](IMPLEMENTATION.md) records the implementation details and verification boundary. The flows below continue to describe the browser reference, including its simulated future tools.

## One shared home

“Small tools. Good company.” is the main brand line. It introduces the collection with warmth; individual tool screens use concrete copy to explain what happens next.

Tapas is a collection of small tools that produce useful results where the user already works. The pintxo joins them into one identity. The four ingredients are a fixed brand mark, not a product count. Tools have distinct glyphs and names; accents can be reused. Dictado and Acta share the full four-color identity. A fifth tool adds a catalog entry without changing the logo or waveform. See [product and identity strategy](../../PRODUCT_STRATEGY.md).

The menu-bar home, “Your plate,” contains Tools, Recent and Preferences. The first public release includes Dictado and Acta. The development preview identifies Acta as unfinished; release builds must have both tools working. Uncommitted ideas have no visible cards or promised dates.

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

The pintxo assembles as preparation advances. Permission requests arrive with the action they enable. Dictado onboarding never asks for Acta app audio.

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

### Selected direction: El borde for Dictado

[Explore the signal and its transformation in HTML](dictado-motion.html). El borde is selected for Dictado: a 124 × 28 px top-edge tab, small enough to remain unobtrusive during a short take. It always labels its recording state. The larger cards and pill are no longer presented as competing Dictado directions. The native app now implements this signal at 124 × 28 points; the browser remains its interaction reference.

The waveform is the pintxo itself. The same four shapes keep their order and colors—saffron, cobalt, paprika, olive—as they spread along a horizontal axis and rotate into vertical voice bars. The pick recedes during capture. Opening takes approximately 550 ms. The native bars respond to microphone level as they transform; audio capture never waits for the animation. When capture stops, the shapes gather back onto the pick while Finishing remains explicit. Delivery briefly holds Listo, then settles. The study includes a 3× enlarged view of this same transformation, synchronized with the sample take. The top-edge recording control never grows during the animation.

Idle has no Dictado popup. The shortcut or Start a take begins microphone capture immediately; there is no Ready step to confirm. Show Starting only while the native microphone is opening, then Listening once capture is active. The animation must never delay audio capture. Clicking the active signal finishes a take; hover or keyboard focus reveals Finish and Cancel. Escape cancels. Live words default off in the study and appear in a separate two-line caption when enabled. The caption follows recent words without moving or resizing the recording control; the complete text remains available for delivery. Recovery stays until resolved and may use a larger, readable surface. After successful delivery, show Listo for 1.6 seconds and hide the popup. Cancellation hides it immediately. The enlarged illustration remains visible solely to explain the motion.

Quiet motion and the OS reduced-motion preference switch directly between static forms and preserve labels. Production movement must follow the actual audio level; the HTML uses scripted animation. The native signal should stay on the display where the take began and preserve destination focus. Place El borde below both the menu bar and camera cutout with a small gap. On MacBooks, use the display’s actual [safe-area insets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets) and visible frame rather than fixed notch dimensions; do not cover the camera housing or adjacent menu-bar controls. Recalculate for display configuration and menu-bar changes, including full screen. The HTML camera-notch toggle is a geometry simulation, not hardware detection. Do not move it in response to individual words.

### Shared family: the floating pintxo for Acta

The floating 82 × 78 px El pintxo is a promising companion direction for Acta’s longer conversations. This is a visual exploration, not a finalized meeting interaction: microphone and app-audio status, elapsed time, pause/resume, and recovery still need to be designed together. The current shape preview uses the sample Dictado take solely to explore presence and movement. Both tools share the four ingredients and the assemble → active → gather → settle motion language. Dictado expresses it as a minimal voice signal; Acta may keep a more persistent companion.

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

**Your files are the interface.** Saving creates a readable file the person can
open in an editor, use from a script, or give to an agent harness they build
themselves. File access does not depend on a Tapas account or MCP server. Future
integrations should offer convenience while preserving this direct path.

The product demonstration should follow capture → saved Markdown → a user-chosen
script or agent operating on the file. Separate the agent's actions from Tapas's
capture behavior, and label simulated or future steps. The current native
preview saves history only when enabled and redacts that saved copy; the
decision about preserving a full transcript by default is still pending.

Recent filters the sample library by title, content and tool. Open shows readable content, its intended destination, Copy text and Export .md. Export generates a real browser download labeled as prototype sample content. The preview does not write into the displayed native folder.

Preferences expose the dictation shortcut, live-word overlay, history saving and simulated paste access. Native Accessibility access belongs to macOS; the prototype toggle exists to explore both states. Preferences and history reset on reload. Clipboard failures direct the user to export.

## Motion, access and implementation boundaries

- Ready is quiet. Listening, working and completion have distinct, brief shape behaviors.
- Keep status labels, visible keyboard focus, meaningful button names and reduced-motion alternatives.
- The responsive browser layout supports reviewing the design on small screens; Tapas remains a macOS product.
- Error messages identify what failed, what was retained and the next useful action.
- The journey rail, failure scenarios and simulated desktop belong to the design viewer, not the product UI.
- Native adoption must connect these surfaces to real permissions, audio state, model progress, persistence, focus restoration and file handling. The HTML does not replace those systems.

## Validation

The maintained browser journeys are onboarding, Dictado, Acta and Your plate. Capture and file-search experiments were removed from the product preview; their ideas remain in the private backlog. Native implementation and live-device verification are tracked separately in IMPLEMENTATION.md.

Current browser checks cover the two-tool catalog, four maintained journeys, history filtering, preferences, Dictado start/cancel, Acta pause/background/save, narrow layouts, and safe fallback from retired links. The focused Dictado study also checks hidden idle, immediate listening, delivery/cancel dismissal, and menu/camera clearance on notched and regular displays.
