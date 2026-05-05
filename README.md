# NodeGet Monitor for iOS

A native SwiftUI monitor app for NodeGet.

This repository is currently at the MVP stage. The first goal is to produce an unsigned IPA from GitHub Actions so it can be signed locally with an Apple ID signing tool and installed on a personal iPhone for testing.

## Current features

- Native SwiftUI shell
- Demo dashboard
- NodeGet JSON-RPC client
- `nodeget-server_hello` connection test
- GitHub Actions core build
- GitHub Actions unsigned IPA build

## Planned features

- Server profile storage
- Token storage using Keychain
- Agent UUID list
- Latest CPU, memory, disk, network, and GPU metrics
- Historical charts
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
- Tokens stay on device and will be stored in Keychain.
- Agent UUIDs and monitoring data are not uploaded to the app developer.
- Anonymous usage statistics, if added, will be opt-in and will not include server URL, token, UUID, or monitoring data.

## License

MIT
