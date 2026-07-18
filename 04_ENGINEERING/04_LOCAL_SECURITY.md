# Local Security and Privacy Architecture

## Threat model

Protect against:

- casual access by someone holding the unlocked phone;
- sensitive content in notifications;
- sensitive preview in the app switcher;
- unencrypted exports;
- accidental backups;
- third-party SDK collection;
- debug logs containing sexual-health data.

## Controls

### Authentication

- Face ID / Touch ID through LocalAuthentication.
- Optional app PIN fallback stored as a salted verifier in Keychain.
- Automatic relock after configurable inactivity.

### Storage

- Use iOS Data Protection with complete file protection where compatible.
- Store encryption keys in Keychain.
- Encrypt free-text notes and exports using CryptoKit.
- Do not place sensitive values in `UserDefaults`.

### Logging

- Disable sensitive logs in release.
- Use redacted identifiers.
- Never log assessment answers, symptoms, notes, or session events.

### UI privacy

- Replace app content with a neutral privacy cover when inactive.
- Use neutral notification titles.
- Hide explicit widget content.
- Provide a discreet app-name display mode inside the UI; actual bundle name remains governed by build configuration.

### Network

MVP should have no network code. Add a CI check that fails if new URLSession usage or networking entitlements appear without review.

### Export

- User chooses a password.
- Generate encrypted ZIP or JSON package.
- Warn that sharing leaves the protected app environment.
- Never export by default.

### Deletion

“One tap delete all” must remove:

- SwiftData store;
- Keychain entries;
- local notifications;
- cached HealthKit summaries;
- export temp files;
- app preferences.
