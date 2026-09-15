# Notices

## Desert Ant Labs

Dictado and Acta embed on-device models from [Desert Ant Labs](https://desertant.com).

License: [Desert Ant Labs Source-Available License, Version 1.0](https://license.desertant.com/1.0)
SPDX: `LicenseRef-DAL-Source-Available-1.0`
Canonical text: https://license.desertant.com/1.0.txt
SDK: https://github.com/Desert-Ant-Labs/desert-ant-core (`LICENSE.md` in that repo is a pointer to the same terms)

### What this allows

Ship the models inside Tapas. Unlimited inference per user. You own transcripts.

Free while each model stays under 100,000 monthly active devices on macOS. Above that, write licensing@desertant.com.

### What this requires

- Credit users can find: "Powered by Desert Ant Labs" linking to https://desertant.com. About, Settings, or the App Store listing is enough. Guide: https://license.desertant.com/attribution
- Keep the license and copyright files the SDK ships with.
- Disclose SDK telemetry in the privacy notice. It is a monthly-active-device counter. It does not include audio or text.

### What this forbids

- Redistributing the models or SDKs as a standalone product, model, SDK, or hosted service
- Training, fine-tuning, or distilling a competing on-device model from weights, outputs, or logs
- Reverse-engineering weights
- Stripping or blocking the MAD telemetry

Downloading a model is acceptance of those terms.

Voz is NVIDIA Parakeet TDT 0.6B v3 (CC BY 4.0) converted to Core ML by Desert Ant. Weights unchanged. Their conversion and runtime are under the Desert Ant license.

## Sparkle

Tapas uses [Sparkle](https://sparkle-project.org), the open-source macOS updater,
under its MIT license. Sparkle and its bundled components’ license notices are
included in the app at `Contents/Resources/Notices/Sparkle-LICENSE.txt`.
