# iOS Build and Sideload Guide

## Requirements

- A Mac capable of running the required Xcode version.
- Xcode installed.
- An Apple ID.
- iPhone connected by cable or paired for wireless development.
- A unique bundle identifier.

## Development installation through Xcode

1. Open the project in Xcode.
2. Select the app target.
3. Open **Signing & Capabilities**.
4. Enable **Automatically manage signing**.
5. Select the appropriate Team.
6. Connect and trust the iPhone.
7. Select the physical iPhone as the run destination.
8. Build and run.

Xcode can register the device and create a development provisioning profile when automatic signing is enabled.

## Distribution to registered devices

For a small controlled group:

- use an Apple Developer Program account;
- register device UDIDs;
- create an iOS development or ad hoc provisioning profile;
- archive and export an `.ipa` for registered devices.

## Personal Team considerations

A free Apple ID can be useful for direct development testing, but personal provisioning may have limitations and shorter validity. For stable repeated sideloading, a paid Apple Developer Program account is the practical route.

## Entitlements

MVP:

- Keychain Sharing only if needed across targets;
- HealthKit only when integration is enabled;
- App Groups only for widgets/watch extensions;
- no push notifications;
- no network/background entitlements unless justified.

## Release configuration audit

- Remove debug menus.
- Disable sensitive logging.
- Confirm no networking SDK.
- Confirm local notification copy.
- Verify privacy cover.
- Verify rule/content version.
- Run offline test.
- Run data-deletion test.

## Important distinction

Sideloading does not remove the need for code signing. Every install must be signed with a valid provisioning configuration for the device and distribution method.

## Repository CI artifact

The repository workflow publishes `Tempo-resign-ready.ipa` in the `Tempo-resign-ready-ipa` artifact. It contains one `Payload/Tempo.app`, an ARM64 executable, compiled assets, and an ad-hoc signature. A sideload tool must replace that signature; the raw artifact is not directly installable. Extract the GitHub artifact ZIP first, then provide the contained IPA to the sideload tool. The current deployment target is iOS 17 or later.
