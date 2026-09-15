# Developer ID signing and notarization

Tapas is distributed directly as a Mac app. This requires a **Developer ID
Application** identity (certificate **and its private key**) in this Mac’s
Keychain. An Apple Developer membership alone does not install that identity.
An Apple Development, Mac App Distribution or Developer ID Installer certificate
is not the right identity for this workflow.

## First certificate

If `dist/signing/Tapas-Developer-ID.certSigningRequest` has already been prepared
and its private key imported into Keychain, use that request and start at step 2.
Do not generate a second key for the same request.

1. Open Keychain Access. Choose **Certificate Assistant → Request a Certificate
   From a Certificate Authority**. Enter your account email and name, choose
   **Saved to disk**, and save the CSR. Keep its private key in this Mac’s Keychain.
2. In [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list),
   add **Developer ID Application**, using the current Developer ID intermediate,
   and upload the CSR. Download the `.cer` and open it to install in Keychain.
3. Confirm the identity is available:

   ```sh
   security find-identity -v -p codesigning
   ```

If the certificate was created on another Mac, export/import its identity with
its private key using Keychain Access. Importing the `.cer` alone is insufficient.
Do not commit signing keys, exported identities or account credentials to this repo.

See Apple’s [Developer ID certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates).

## Sign the app

```sh
TAPAS_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  Scripts/package-app.sh dist/developer-id
```

Or sign an already packaged development app without rebuilding:

```sh
TAPAS_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  Scripts/sign-app.sh dist/acta-dev/Tapas.app
```

This enables hardened runtime, adds the audio-input entitlement, requests Apple’s
secure signing timestamp, and verifies the Developer ID certificate requirement.
The script signs Sparkle’s helper executables, XPC services, updater app and
framework before signing Tapas, preserving the helper entitlements. Local packaging without
`TAPAS_SIGNING_IDENTITY` remains ad-hoc signed.

## Notarize and staple

Store credentials once using an interactive terminal. `notarytool` prompts for an
Apple app-specific password; do not put that password in a command, source file or
chat message. Use the Team ID shown in the Developer account.

```sh
xcrun notarytool store-credentials tapas \
  --apple-id 'your-apple-account@example.com' --team-id TEAMID
```

Then notarize the signed app:

```sh
TAPAS_NOTARY_PROFILE=tapas Scripts/notarize-app.sh dist/developer-id/Tapas.app
```

The script submits a temporary ZIP of the app, checks Apple’s Accepted status,
staples and validates the ticket, and runs Gatekeeper assessment. It keeps the
submission response beside the app as `Tapas.app.notarization.json`. If submission
fails or is delayed, use its ID with `xcrun notarytool info` / `log` and the same
Keychain profile. A signing success is not a notarization success.

See Apple’s [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Build the installer

Install the isolated packaging tool once (Python 3.9+):

```sh
python3 -m venv .build/dmg-tools
.build/dmg-tools/bin/pip install dmgbuild==1.6.5
```

`Scripts/dmg-background.swift` draws the Retina background in the app’s palette.
`Scripts/dmg-settings.py` places the real app and Applications shortcut in Finder.
Its explicit file list includes only the app. Privacy and license notices remain
inside the signed app; notarization reports stay outside the disk image.
The build does not require Finder automation or screen-recording permission.

```sh
TAPAS_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
TAPAS_NOTARY_PROFILE=tapas TAPAS_RELEASE_LABEL=0.1.0 \
  Scripts/package-dmg.sh
```

This signs, notarizes and staples both the app and DMG, then verifies Gatekeeper
acceptance and writes a SHA-256 checksum. To reuse a previously packaged app,
set `TAPAS_PACKAGED_APP=dist/developer-id/Tapas.app`. Existing release files are never
overwritten. Signing and notarization do not publish a release.

## Automatic updates

Tapas embeds Sparkle 2.10.0. Its HTTPS feed is
`https://github.com/adgapar/tapas/releases/download/updates/appcast.xml`.
The feed must be published before installed copies can check successfully.
Automatic checks and downloads default to on and can be changed in Preferences.
Recording, recognition, recovery and first-time setup delay update checks/restarts.

The EdDSA private key is in the login Keychain under account `work.tapas.Tapas`.
Only the public key is committed in Info.plist. Keep the Keychain backed up;
do not generate a replacement key for each release.

For every release:

1. Increase `CFBundleVersion` in the app’s Info.plist (0.1.0 is build `3`).
2. Build the signed/notarized DMG with a unique release label.
3. Generate the signed update entry:

   ```sh
   Scripts/prepare-update.sh dist/releases/Tapas-0.1.0-arm64.dmg v0.1.0
   ```

4. Upload the DMG and checksum to that version’s GitHub release, and publish it.
5. Upload the generated `dist/updates/v0.1.0/appcast.xml` to the public
   `updates` release, replacing its previous appcast only after the DMG is live.
6. Verify the public feed and download, then check from an older installed build.

The feed selects the latest full DMG for macOS 15+ on Apple silicon. Archives are
EdDSA-verified before extraction and the app is Developer ID signed and notarized.
Older builds without Sparkle require one manual DMG installation. Building locally
alone does not release updates to installed copies.

See [Sparkle’s distribution documentation](https://sparkle-project.org/documentation/).
