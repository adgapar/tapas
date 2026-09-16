# Development

Tapas is a native macOS app. Use macOS 15 or later on Apple silicon with the
Swift toolchain required by the package manifests.

```sh
swift test
swift test --package-path Apps/TapasApp
swift build --package-path Apps/TapasApp --product Tapas
```

Render sample interface states without recording audio or loading user data:

```sh
Apps/TapasApp/.build/debug/Tapas --render-design /tmp/tapas-design
```

Build a local, ad-hoc signed app:

```sh
Scripts/package-app.sh dist/local
```

For distribution, see [Signing](SIGNING.md). Packaging alone does not publish an
update. Microphone, app-audio permissions and live capture require testing in a
packaged app on real hardware; sample renders do not validate those integrations.
