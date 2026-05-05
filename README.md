# NodeGet Monitor for iOS

A native SwiftUI monitor app for NodeGet.

The current goal is to build unsigned IPAs through GitHub Actions, sign them locally with an Apple ID signing tool, and test them on a personal iPhone before preparing a formal App Store release.

## Current version: 0.5.0

### Features

- Native SwiftUI shell
- Demo dashboard
- NodeGet JSON-RPC client
- `nodeget-server_hello` connection test
- Server profile storage on device
- Token storage using iOS Keychain
- Real Agent UUID list through `nodeget-server_list_all_agent_uuid`
- Agent detail placeholder with UUID copy support
- GitHub Actions core build
- GitHub Actions unsigned IPA build

## Planned features

- Latest CPU, memory, disk, network, and GPU metrics
- Historical charts
- Better empty/error states
- Anonymous opt-in usage statistics
- App Store ready privacy policy and demo mode

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
NodeGetMonitor-unsigned-ipa
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
