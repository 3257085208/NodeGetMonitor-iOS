# NodeGet Monitor for iOS

A native SwiftUI monitor app for NodeGet.

The current goal is to build unsigned IPAs through GitHub Actions, sign them locally with an Apple ID signing tool, and test them on a personal iPhone before preparing a formal App Store release.

## Current version: 0.7.0

### Features

- Native SwiftUI shell
- Native monitor tab with multi-backend Agent aggregation
- Asset tab with currency conversion and renewal/expiry overview
- Control tab inspired by NodeGet-board
- NodeGet JSON-RPC client
- Server profile storage on device
- Token storage using iOS Keychain
- Real Agent metrics, ping/tcp_ping quality, trend sampling, and KV metadata
- Read-only control modules for Agents, Tokens, Crontabs, KV namespaces, and JS Workers
- GitHub Actions core build
- GitHub Actions unsigned IPA build with versioned IPA filenames

## Planned features

- Token create/edit/delete workflows
- Crontab create/edit/enable/disable workflows
- KV metadata editing
- Add Agent install wizard
- Batch execute with explicit safety confirmation
- Web terminal / config editor if iOS distribution constraints allow it

## Build core package

```bash
swift build
swift test
```

## Generate Xcode project locally

This project uses XcodeGen for the iOS app project.

```bash
brew install xcodegen
xcodegen generate
open NodeGetMonitor.xcodeproj
```

## Build unsigned IPA on GitHub

Go to:

```text
Actions -> Build Unsigned IPA -> Run workflow
```

After the workflow finishes, download the artifact named:

```text
NodeGetMonitor-v0.7.0-unsigned-ipa
```

Then sign the IPA with your Apple ID signing tool and install it on your iPhone.

## Privacy direction

The intended app design is privacy-first:

- NodeGet server URLs stay on device.
- Tokens stay on device and are stored in Keychain.
- Agent UUIDs and monitoring data are not uploaded to the app developer.
- Anonymous usage statistics, if added, will be opt-in and will not include server URL, token, UUID, or monitoring data.

## License

MIT


## v0.4.0

Adds dashboard detail modules for dynamic summary history, Task ping/tcp_ping quality, KV metadata billing fields, online strip, and trend placeholders.


## v0.7.0

Adds the first native Control tab, based on the uploaded NodeGet-board project. It includes backend status, Agent management, Token list, Crontab list, KV namespace browsing, JS Worker/script browsing, and a dashboard-style feature entry layout. Destructive operations are intentionally read-only in this first native control release.
