# One home, small tools — interaction review

**Status: proposed design; release paused.** Open [the clickable study](interactions.html).
This supersedes the separate-window navigation in the earlier study for review.
The current public app remains 0.1.1. Native work in progress is not a release candidate.

## One visual language

Keep Gráfico’s warm paper, ink outlines, saffron, cobalt and four-piece Pintxo.
Use one type scale, spacing system, button family, inline status and error style
across Dictado, Acta, Preferences and setup. Distinguish tools with their name,
glyph and accent, not unrelated layouts. Primary actions are explicit verbs. Use the bold lowercase **tapas** wordmark,
Pintxo logo and paprika slash consistently in the main window, meeting invitation
and companion controls; keep Acta as a secondary tool label.
macOS permission dialogs, folder pickers and title-bar controls remain native OS
surfaces; the prototype labels their simulations outside the real product flow.

## Everyday home: the floating plate

The everyday app now uses a compact frameless plate with the lowercase tapas
identity, an explicit close button, and a persistent Tools / Recent / Preferences
control. It keeps the Open-stage visual language at a smaller everyday scale.

- Dictado and Acta have equally weighted cards, distinct illustrations, readiness
  labels, the saved shortcut and a clear primary action.
- Dictado starts/finishes a take. During Acta it explicitly says Pause Acta & talk.
- Acta opens its controls; an active meeting shows status, elapsed time and Return
  above the cards. Opening a tool never silently starts meeting capture.
- The latest saved transcript appears below the cards and opens its Recent detail.
  Before anything is saved, show an honest empty state instead of example files.
- Tool pages, Recent and Preferences use the same floating header/navigation with
  one readable content panel. All tools remains a clear return path.
- Your files opens the shared folder; folder selection remains in Preferences.
- A background save can show a Pintxo receipt. Once the saved result is opened,
  clear that receipt so it cannot cover other controls.
- Narrow review layouts stack the cards; normal Mac layouts place them side by side.
  Artwork is quiet at rest; it is not an indication that audio is recording.

## One home and predictable navigation

- Dock and menu-bar entry points open the same shared home.
- Tools gives Dictado and Acta equal prominence and explains their purpose.
- Dictado starts a short take directly. Acta opens meeting controls.
- Each tool has **All tools**. Tools, Recent and Preferences remain reachable.
- Navigation never silently cancels a recording, discards text, or starts capture.
- Closing a window keeps an active meeting running with a visible companion.
- Pintxo is the floating companion: its persistent label shows recording state and time.
  Clicking it opens Pause/Resume, Finish & save and Open meeting controls.
- Dictado pauses an active Acta meeting. Resuming Acta is explicit.

## Current exploration: Open stage

The First launch scenario now defaults to **Open stage**, a frameless split
presentation on the simulated desktop. **Window** in the review rail retains the
previous layout for comparison. Switching variants preserves progress and choices;
neither is yet a shipped native experience.

- The lowercase tapas identity floats above the scene, with a visible close action.
- One side is an animated Pintxo scene; the other is the current action card.
- Welcome assembles four ingredients; Access surrounds Pintxo with permission
  labels that update only when granted; Files places two Markdown slips in the
  shared folder; practice turns the same Pintxo into the audio waveform.
- The horizontal ingredient progress sits below the split scene. Back and Finish
  later remain in consistent locations. The default app tabs do not appear here.
- Step transitions are brief. Permission changes do not replay the whole scene.
  Animation never delays permission requests or recording state. Reduced motion
  keeps the same content and statuses static.
- Narrow layouts stack a compact illustration above the action card. The review
  comparison buttons are outside the product UI.

In a native version, “frameless” would still use an accessible AppKit window with
keyboard focus, close/reopen behavior and system permission sheets. No desktop
wallpaper changes, app hiding or system-wide overlay is implied by this study.

## First launch: Welcome → Access → Files → First taste

Installation remains drag Tapas into Applications in the DMG. Opening the app
for the first time then presents a dedicated wide welcome window, before the
regular Tools / Recent / Preferences interface. Installing an update does not
repeat first-launch onboarding. Setup can later reopen the same flow explicitly.

Keep the lowercase tapas/logo header. Four colored ingredients sit on a
horizontal pick as the progress indicator, with the current step emphasized.
A serving plate and horizontal Pintxo bring the “setting the table” idea to the
illustration. The plate is a supporting shape; Pintxo stays the single character.
Use culinary language lightly, and keep permission and file actions literal.

The wide window pairs illustration and instructions side by side. At narrow
review widths, the illustration folds away while the horizontal progress remains.
The everyday app tabs and file footer are absent in this welcome window. Back,
Finish later and the close control remain available. Leaving and returning resumes
the current step without losing granted permissions or a confirmed folder.

1. **Welcome.** Introduce Dictado and Acta, on-device speech and local files.
2. **Access.** Microphone serves both tools. Accessibility serves both global
   shortcuts and Dictado paste; Acta recording from buttons does not require it.
   Separately offer **Meeting audio · Acta**, named Screen & System Audio
   Recording by macOS. Users can enable it now or on first meeting. Every request
   follows an explicit Allow action. Denial stays visible and does not trap users.
3. **Files.** Confirm the suggested Documents/tapas folder or choose another one.
   Show dictado and acta as the two subfolders. Continue follows explicit folder
   confirmation. This configures the same shared preference, not an Acta setting.
4. **First taste.** Prepare local voice models, then start and finish a practice
   take inside onboarding. Show the resulting sentence here, with no external
   paste and no saved history entry. Cancel an unfinished practice when leaving
   or closing the window; don't resume capture on reopening. The final action
   opens the everyday tool home. Practice can be skipped. Explain Acta's automatic
   suggestion and that recording always needs consent.

**Selecting a folder, never typing a path:** the native app uses NSOpenPanel
configured for directories, with a suggested starting location and Choose/Cancel.
The HTML simulates that sheet with selectable example folders. It does not read
the actual filesystem or ask for browser directory permissions. No editable path
field exists. Cancel leaves the current folder unchanged; unwritable destinations
show an error and retain the previous setting. Preferences invokes the same picker.
Granting permissions, choosing a folder or downloading models never starts capture.

## Meeting detection → suggestion → capture

1. Detect another app’s microphone use without calendar, MCP or conferencing integrations.
2. After a short stability check (target 1–3 seconds), show a nonactivating prompt
   on the active display. It must not require model preparation or completed setup.
3. State exactly what was detected: **Chrome is using your microphone.** Microphone
   use is a hint, not proof of a meeting. Do not claim to know a Google Meet tab.
4. Keep the prompt until the user responds or the microphone-use episode ends.
   Never silently expire after 30 seconds. Do not steal typing focus.
5. **Record meeting** uses the detected app when all prerequisites are satisfied.
   The invitation settles into the compact Pintxo companion; keep the call in focus
   without opening the full Tapas window.
   **Set up & record** opens Acta when preparation is needed, with the app selected.
6. After granting prerequisites, require an explicit **Record meeting** action.
   Permissions or returning from Settings must never themselves start capture.
7. **Not now** suppresses repeat prompts for that episode. Microphone device
   switches and brief dropouts must not cause repeated suggestions.
8. Defer prompts during an active Dictado take; do not offer a second Acta meeting.
9. Surface unavailable detection in Tools/Preferences with retry and manual entry.
10. If a selected app disappears, explain the loss and ask for a new selection;
    never silently record another app.

The prototype’s “Join a Meet call” button simulates detection immediately. Native
latency, helper-process attribution, muted starts, browser differences, full-screen
Meet and reconnect behavior need real-device checks before release. A browser
microphone hint cannot detect every call, especially a call with no microphone use.

### Current implementation findings, not a confirmed diagnosis

The released flow gates suggestions on models ready, setupComplete and other busy
states. Its floating prompt expires after 30 seconds. The policy includes a
three-second debounce and sixty-second cooldown/rearm. These can hide or delay
suggestions; there is not enough runtime evidence to attribute the reported Meet
failure to a specific gate. Validate Google Meet in the user’s browser on-device.

## Pintxo carries the meeting interaction

The suggestion and recording companion share one anchor near the lower-right
edge of the active display, clear of the Dock. The four faceless ingredients
assemble on their pick once, with a small speech bubble: **Keep this conversation?**
The detection detail, explicit Record meeting and Not now remain visible.
No attention-seeking bounce loops. Reduced motion shows the assembled mark directly.

After acceptance, the invitation gives way to the same Pintxo with a persistent
**Recording · time** label. The exact same four ingredients separate, rotate into vertical bars, and become
an audio waveform; the pick fades. A 900 ms transition visibly separates the pieces, spreads them, then turns them
into bars; pause/save reverses the journey. The 80 × 96 mark area stays fixed.
The study rail includes Replay Pintxo motion. Capture state updates immediately;
the visual transition never delays recording. The bars
react to a scripted envelope in this prototype, including periodic quiet moments.
The recording label and timer remain visible during silence. Pause and Saving
gather the ingredients onto the pick, and Saved retains the assembled mark.
Reduced motion keeps the assembled Pintxo static with the same status text.
Native waveform heights must follow actual audio levels, never random motion. Text labels always identify state.
Click or keyboard-activate Pintxo to toggle controls without opening the app.
The compact token is the primary presence; its controls are an anchored speech
bubble, not a second window. Save failure opens recovery controls and a successful
save gives an Open transcript receipt. Not now dismisses the entire invitation.
First-time prerequisites open the shared Acta setup page; granting access never
starts recording by itself. All animation and audio activity here are simulated.

## Audio source and permissions

**Where is your meeting?** selects the source of the other participants’ audio.
Your microphone supplies your own voice. Detected apps are preselected; manual
entry starts with an explicit choice. A browser may include sound from other tabs.
The MVP continues to capture one app, not all system audio.

| Capability | Explain and request | If unavailable |
| --- | --- | --- |
| Microphone | Captures your voice; ask during setup or first capture | Allow / Open System Settings; keep navigation available |
| Meeting audio | Screen & System Audio Recording; offer in onboarding or ask on Acta’s permission step | Explain where to enable Tapas, check on return, mention reopening only when needed |
| Shortcuts and paste | Accessibility; ask in setup or Preferences | Buttons and copying remain available; do not block Acta recording |
| Local voice models | Prepare once; show real download progress in production | Resume/retry preparation without losing the detected source |

No screen images are saved by Acta. Background microphone detection must never
trigger a screen-recording permission request. Permission grant and denial both
have a clear route back into the shared window.

## States and recovery

| State | User can do | Capture |
| --- | --- | --- |
| Ready | Choose source, grant prerequisites, Record meeting | Off |
| Recording | Pause, Finish & save, navigate, close window | Microphone and selected app |
| Paused | Resume, Finish & save, export, discard with confirmation | Off |
| App interrupted | Understand which source failed, fix it, explicitly resume | Both inputs paused |
| Finishing | Navigate and see progress; no duplicate finish or new recording | Off |
| Saved | Open transcript, show folder, start another meeting | Off |
| Recovery | Retry transcription/save, export available text, confirm discard | Off |

No individual speaker attribution is promised: label Microphone / App audio.
Active elapsed time excludes pauses. The source paths and text remain available
through navigation. A failed save must retain temporary audio and text durably in
the native app. Do not restart for an update with unfinished work.

## Preferences and files

- Separate Dictado and Acta shortcut settings. Proposed defaults: Control–Option
  and Control–Shift–M. Acta shortcut opens controls and never starts recording.
- Record/edit/reset shortcuts. Reject conflicts, including modifier-prefix overlap.
- **Preferences → Transcript folder** is the only folder setting, shared by both tools.
  A parent folder contains dictado/ and acta/. Choose / Open / Use default.
  Acta preflight has no folder field or path; the saved receipt may show the actual
  file location so the user can find the result.
- Apply folder changes to new recordings. In-flight work and retries retain their
  original destinations. Do not move or delete old files as a preference side effect.
- Meeting suggestions, live words, Dictado history, permission management and
  automatic updates use the same settings treatment.
- Recent supports search, readable file content, copy and Markdown export.

## Review paths

1. Everyday home → Dictado → start/finish → Recent → Preferences → Tools.
2. Join a Meet call → Pintxo invitation → Record meeting → compact Pintxo → click for controls → pause/resume → Open meeting → finish.
3. First meeting → Set up & record → microphone + meeting audio → prepare → record.
4. Deny access → navigate elsewhere → return → grant access → record explicitly.
5. Record Acta → Dictado → Acta remains paused → finish take → resume Acta.
6. Record → change transcript folder → finish → confirm original output path.
7. Folder unavailable → Finish → recovery → navigate → export/retry.
8. Interrupted meeting → export or retry; discard offers a cancel path.
9. Close shared window → reopen from Dock; companion remains reachable.
10. Edit shortcut → reject overlap → accept distinct binding → Escape cancels.

## Prototype boundaries

All audio, permission, detection, OS windows, model preparation and file paths
are simulated in memory. Reload resets everything. Export downloads sample
Markdown and Copy uses the browser clipboard. No audio, screen, real folder or
account access occurs. Keyboard demos only work while the browser page is focused;
browser/OS-reserved chords may be intercepted. Screen layouts respond to narrow
review viewports; Tapas remains a macOS app.

The study intentionally uses instant simulated model preparation and sample
transcript text. Production model progress, save/retry durability, OS return and
restart handoff, actual shortcut registration, update installation, and live
meeting detection require native implementation and device verification after
the interaction review. No version bump, installer, appcast or release is part
of this design pass.

## Browser verification · 16 September 2026

Checked in an isolated Chrome browser at 1440 × 1040 and 390 × 1000, including
reduced motion. The walkthrough passed prompt acceptance/dismissal, first-use
and denied permissions, explicit start after preparation, shared navigation,
background controls, Dictado pause handoff, original-folder saving after a
preference change, app interruption, save recovery and retry, canceled discard,
shortcut conflicts/edit/Escape, setup exit, and Dock reopen. No page JavaScript
errors or horizontal overflow were observed. Screenshots were inspected locally.
This validates the simulated interaction study, not macOS capture or detection.

### Pintxo revision verification

Rechecked the shared-only folder setting, four-ingredient invitation, recording
without opening the main window, click and keyboard controls, pause/resume,
background save receipt, dismissal, first-use permission denial/grant, recovery
and retry, reduced-motion behavior, and 390-pixel layout containment. No page
errors were observed. Invitation, compact recording and expanded-control
screenshots were inspected. Native implementation remains paused.

### Waveform and wordmark verification

Verified the explicit 900 ms unfolding animation and intermediate frame, four
aligned bars with scripted level changes, quiet moments with Recording still
visible, the reverse gathering transition on pause, resumed motion, and the
static assembled mark under reduced motion. The ingredient DOM nodes persist
across control changes and the mark area remains 80 × 96. Checked the lowercase
tapas/logo treatment in invitation, home and controls; desktop/mobile layouts
had no page errors. This remains a simulated HTML study, with no native release.

### Onboarding and folder-selection verification

Checked all four stages, optional permission skips, microphone denial/retry,
Acta audio grant without capture, setup resume after leaving, explicit default
folder confirmation, alternate-folder selection, cancellation, unwritable-folder
failure retaining the prior setting, and the shared value in Preferences.
The dialog has only folder radio choices and no editable path field. Desktop
and 390-pixel screenshots were inspected; no page errors or horizontal overflow.

### Dedicated first-launch revision

This replaces the earlier embedded setup screen. The horizontal ingredient flow,
serving plate and in-window practice form the current onboarding proposal. The
HTML simulates an initial launch via the First launch scenario; remembering
completed onboarding across actual installs/updates remains native app behavior.

The dedicated first-launch flow passed browser checks for hidden everyday tabs,
four horizontal ingredient steps, permission denial/retry, folder selection shared
with Preferences, leaving/resuming setup, practice cancellation on window close,
practice completion without history or external paste, and transition into the
normal tool home. Desktop and narrow-layout screenshots were inspected; no page
errors or horizontal overflow were observed.

### Open-stage verification

Checked the frameless layout and visible close action, state-preserving comparison
with Window, the same persistent four-piece scene through permission/folder steps,
permission labels following actual simulated grants, selection-only folders,
practice waveform with scripted levels, reduced-motion static state, no practice
history, completion into Tools, Dock reopen and narrow-layout containment.
Desktop and mobile screenshots were inspected; no page JavaScript errors occurred.

### Everyday-home verification

Verified equal tool cards, empty/latest-file states, latest-file navigation into
Recent, Dictado start/finish, shared folder selection in Preferences, Acta status
and timer, pause-for-Dictado handoff, finish/save into the latest-file preview,
close/Dock reopen, returning from Open-stage setup, and narrow-screen navigation.
A saved receipt overlapping onboarding was found and fixed: foreground saves do
not create a floating receipt, and opening a saved result clears any background
receipt. The final walkthrough passed with no page errors or horizontal overflow.
Desktop and narrow-layout screenshots were inspected. Native release stays paused.

## Native implementation · 0.1.2

The reviewed everyday home, Open stage welcome, shared folder picker, Acta
shortcut, explicit permission actions, persistent meeting invitation, and Pintxo
companion are now connected in SwiftUI/AppKit. Both Dock and menu-bar entry use
one home window. Separate light surfaces keep text readable over dark desktop
wallpapers; there is no enclosing window background. Windows fit the active
screen’s usable area. Files and recording lifecycles remain owned by the core
sessions, independently of these views.

Onboarding has four stages, optional permissions, explicit folder confirmation,
and private practice with no paste or history. Closing cancels capture and lets
an already-finishing practice complete safely. Completion does not force users
to download models or grant optional permissions; Tools shows remaining setup.
Existing completed onboarding is preserved on updates.

Verification: 89 core tests and 11 native tests cover recording/recovery,
original-folder retention (including older checkpoints), shortcut capture and
key consumption, folder validation, onboarding advancement and cancellation,
and accepting an invitation without permission. Native renders cover the home,
Preferences, all onboarding stages, Acta states, and a smaller display fit.
Renders use fixture content and never capture microphone or desktop content.
Live meetings, OS permission dialogs, and capture behavior across hardware and
Spaces still require the device checks in [Acta](../../docs/ACTA.md).
