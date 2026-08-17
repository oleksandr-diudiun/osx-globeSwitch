# GlobeSwitch

GlobeSwitch is a personal native macOS menu-bar app that switches directly between:

- `com.apple.keylayout.ABC` (`EN`)
- `com.apple.keylayout.Ukrainian-PC` (`UA`)

It uses an active Core Graphics event tap and calls Apple's Text Input Sources API
synchronously on the **Globe/Fn key-down** event. There is no language HUD, animation,
mouse interaction, synthetic keyboard shortcut, shell process, or intentional delay.

## Required macOS setup

1. Open **System Settings → Keyboard**.
2. Set **Press Globe key to** to **Do Nothing**.
3. Launch GlobeSwitch and choose **Request Keyboard Access…** from its menu-bar menu.
4. Enable the app in the privacy pane macOS opens, then relaunch it if required.

The system setting is important: leaving it on **Change Input Source** makes the native
handler and GlobeSwitch both react to the same key.

## Deliberate trade-off

GlobeSwitch optimizes for typing speed by switching on key-down, not key-up. Globe/Fn
is therefore treated as a dedicated language key. Using it as a modifier can also
change the language. Quit or pause GlobeSwitch before relying on Globe/Fn shortcuts.

## Build and run

```bash
./script/build_and_run.sh
```

Verification:

```bash
swift test
./script/build_and_run.sh --verify
```

The staged bundle is `dist/GlobeSwitch.app`.

## Personal installer

Build the Apple Silicon release app and DMG installer:

```bash
./script/package_release.sh
```

The script performs a release build, stages a hardened-runtime ad-hoc signed app,
validates its bundle identifier and architecture, creates and verifies a compressed
DMG, and writes SHA-256 checksums. Release artifacts are kept in Git so the last
known-good installer can be restored without Xcode:

```text
release/
├── GlobeSwitch.app
├── GlobeSwitch-0.1.0-arm64.dmg
└── SHA256SUMS.txt
```

The DMG includes an Applications shortcut and Ukrainian installation instructions.
It is intended for this Mac and is not Apple-notarized.

The measurements, design trade-offs, alternatives, and current verification state
are recorded in [`INVESTIGATION_2026-08-17.md`](INVESTIGATION_2026-08-17.md).

## Permissions and local signing

The app needs macOS keyboard-event permission for its active event tap. The local
bundle is ad-hoc signed because this Mac currently has no Developer ID or Apple
Development code-signing identity. Rebuilding can therefore require granting the
permission again. A stable personal signing identity is the durable fix for updates.
