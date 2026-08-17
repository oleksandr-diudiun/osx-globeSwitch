# Globe/Fn input-source switching investigation — 2026-08-17

## Goal

Switch between English and Ukrainian from the physical Globe/Fn key before the
next typed character, without macOS's language HUD, animation, mouse-sensitive
overlay, or synthetic shortcut.

## Observed on this Mac

- macOS 26.5.2 (25F84), Apple Silicon M2.
- Enabled selectable keyboard layouts:
  - `com.apple.keylayout.ABC`
  - `com.apple.keylayout.Ukrainian-PC`
- Selected source at investigation time: Ukrainian-PC.
- `com.apple.HIToolbox AppleFnUsageType = 1`, which maps to the System Settings
  action **Change Input Source**.
- The built-in Apple keyboard exposes the Fn/Globe modifier and Core Graphics
  defines it as `kCGEventFlagMaskSecondaryFn`.

## Direct API benchmark

A temporary Swift benchmark called `TISSelectInputSource` 100 times, alternating
the two enabled keyboard layouts and restoring the original source afterwards.

| Measurement | Time |
|---|---:|
| Minimum | 0.003 ms |
| Median | 0.004 ms |
| 95th percentile | 0.006 ms |
| Maximum | 1.002 ms |

This proves that the direct selection call itself is not the source of the visible
delay. It does **not** yet prove the complete physical-key-to-first-character
latency; that requires a real Globe-key test after macOS grants keyboard access.

The macOS 26.5 SDK still declares `TISCreateInputSourceList`,
`TISCopyCurrentKeyboardInputSource`, and `TISSelectInputSource` as available from
macOS 10.5 and does not mark them deprecated.

## Chosen design

`GlobeSwitch` installs an active session event tap for `flagsChanged`, recognizes
virtual key code 63 with the secondary-Fn flag, and calls `TISSelectInputSource`
synchronously on the transition to key-down. The callback passes the original
event through after the selection call.

Switching on key-down is intentional. Waiting for key-up would preserve every Fn
chord but would reintroduce a race when the next letter overlaps the Globe release.
The consequence is that Globe/Fn is treated as a dedicated language key while the
app is active. A menu command pauses the monitor when Fn shortcuts are needed.

The status-item UI update is deferred until after the event callback returns. No
diagnostic file I/O occurs on the hot path.

## Required system setup

Set **System Settings → Keyboard → Press Globe key to → Do Nothing**. Otherwise
the native Globe handler and GlobeSwitch both process the same press. Apple lists
Do Nothing as a supported Globe/Fn action; the private preference value is only
used for detection, not silently changed by GlobeSwitch.

The active event tap requires macOS keyboard-event permission. The app requests
the relevant system access and retries event-tap creation after permission is
granted.

## Alternatives considered

1. **Apple's Control-Space input-source shortcut** — minimal and official, but it
   does not preserve the requested Globe-key workflow and still routes through the
   general shortcut handler.
2. **Karabiner-Elements** — can intercept Fn/Globe at a lower level and has a native
   `select_input_source` action. It is a capable fallback but adds a virtual-keyboard
   driver and a much larger configuration surface for one two-layout switch.
3. **Hammerspoon** — exposes `hs.eventtap` and `hs.keycodes.currentSourceID`, making
   a Lua prototype easy. It still requires a general automation runtime and its
   event callbacks are not narrower than the small native app.
4. **Caps Lock switching** — supported by macOS for Latin/non-Latin pairs, but it
   changes the user's chosen key and does not address the Globe interaction itself.

## Verification status

- Direct input-source benchmark: passed.
- Swift 6 build: passed.
- Core state tests: 2 passed.
- App-bundle build, ad-hoc signing, launch and process verification: passed for the
  first build.
- Final source after adding Pause/Resume: builds and tests successfully.
- Apple Silicon release app and DMG: built successfully; the bundle passed strict
  code-signature, identifier, architecture and Info.plist validation, and the DMG
  passed `hdiutil verify`.
- Real physical Globe press with permission granted: pending user test.

## Primary references

- Apple Support: [Keyboard settings on Mac](https://support.apple.com/en-gb/guide/mac-help/kbdm162/mac)
- Apple Developer: [CGEventTapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29)
- Apple Developer: [CGEventFlags](https://developer.apple.com/documentation/coregraphics/cgeventflags)
- Installed macOS 26.5 SDK:
  `Carbon.framework/Frameworks/HIToolbox.framework/Headers/TextInputSources.h`
- Hammerspoon: [hs.keycodes](https://www.hammerspoon.org/docs/hs.keycodes.html)
- Karabiner-Elements source/docs: [`select_input_source`](https://github.com/pqrs-org/Karabiner-Elements/issues/3547)
