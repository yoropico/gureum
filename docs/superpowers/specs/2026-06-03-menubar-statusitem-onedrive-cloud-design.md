# Design: Gureum status-bar cloud indicator (OneDrive-style wide cloud)

Date: 2026-06-03
Status: Approved, pre-implementation. Builds on
`2026-06-03-menubar-cloud-square-redesign.md`. Scope: macOS app target (`OSX`) —
asset catalog + generator + `GureumAppDelegate.swift`. No Info.plist, no input
hot-path (InputController/InputReceiver/Composer) change.

## Why

The menu-bar input-source icon slot (`tsInputModeMenuIconFileKey`) is a FIXED
SQUARE, so a wide cloud is aspect-distorted into it (the original squish). The
OneDrive menu-bar cloud avoids this only because OneDrive is a **status-bar app
(NSStatusItem)** — a status item slot is **width-flexible**, so a wide image is
shown undistorted. The user wants that OneDrive look. So we add Gureum's own
NSStatusItem with a wide cloud, while ALSO fixing the system input-source icon so
it is not distorted either way.

## Two layers

### Layer 1 — system input-menu icons (8 imagesets): square letterbox cloud
The 8 existing imagesets (`eng, qwerty, han, han2, han3, han390, han3final,
hanroman`) stay SQUARE (matches the square slot) but hold a **pretty natural-
proportion cloud letterboxed** (centered, transparent above/below) — undistorted,
just a bit shorter than the tile. This fixes the original bug for users who keep
the system input menu visible.

### Layer 2 — NSStatusItem: wide OneDrive-style cloud (the feature)
- **Created in** `GureumAppDelegate.applicationDidFinishLaunching`. The IME is a
  persistent agent process (it already shows windows/About/Preferences and runs
  `NSApplication.shared.run()`), so a status item lives for the process lifetime.
- **Image**: a **wide (natural-proportion) cloud** template — Korean = FILLED,
  English = OUTLINE. The status-item slot is width-flexible, so it shows
  undistorted. Template → auto light/dark tint.
- **Update signal**: observe the distributed notification
  `kTISNotifySelectedKeyboardInputSourceChanged`. On each change (and at launch)
  read `TISCopyCurrentKeyboardInputSource()` and classify. **No edit to the input
  hot path** — Gureum already calls `selectMode()` (InputController.swift:156),
  which moves the selected input source, which fires this notification.
- **Visibility**: shown only when the current input source is a Gureum source;
  hidden when another IME is active (avoids a confusing stray cloud).
- **Click**: a small NSMenu (환경설정… / 업데이트 확인… / 정보…) wired to new
  methods on the app delegate (the existing `menu` outlet targets InputController
  via the responder chain, which a status item can't reach — so a small dedicated
  menu is cleaner).

## Classifier (the one unit-tested piece)

Pure function, no UIKit/AppKit state:

```
enum CloudState { case korean, english, hidden }
func classify(inputSourceID: String, primaryLanguage: String?) -> CloudState {
    guard inputSourceID.hasPrefix("org.youknowone.inputmethod.Gureum.")
        else { return .hidden }                 // non-Gureum source -> hide
    return primaryLanguage == "ko" ? .korean : .english
}
```

Matches the system's own ko/en icon choice (Info.plist `TISIntendedLanguage`).
Verified by a standalone Swift check (the XCTest target would require a pbxproj
edit; per session gotcha #10 we avoid pbxproj surgery, so the pure function is
exercised by a throwaway `swift` script instead).

## Duplication (two clouds)

Both clouds are undistorted and pretty. A user who wants ONLY the OneDrive-style
wide cloud turns off System Settings → Keyboard → "Show Input menu in menu bar".
There is no public API to toggle that, so we **document it** rather than automate.
Default: both show, both fine.

## Assets / generation

`OSX/Icons/generate-menubar-icons.swift` renders the SAME smooth cloud (union of
round lobes over a flat-bottomed rounded base — OneDrive-like) two ways:
- **square** (letterbox) → the 8 system imagesets, 16×16 / 32×32.
- **wide** (fills its natural aspect) → 2 new imagesets `statushan` (filled),
  `statuseng` (outline), height 16/32 px, width = round(height × cloud-aspect).

All template (black + alpha); `Contents.json` `template-rendering-intent:
template`. Outline = filled silhouette minus its morphological erosion (even-width
contour of the exact same shape).

## Implementation order (de-risked)

1. Generator: emit square (8) + wide status (2) assets; add the 2 imagesets.
2. StatusItemController inside `GureumAppDelegate.swift`; classifier + standalone
   check.
3. Wire into `applicationDidFinishLaunching`; click menu methods on the delegate.
4. Signed build → install → **on-device verify (R1 first): the status item
   actually appears**; then wide cloud, ko/en toggle, dark/light, and the system
   menu square cloud is undistorted.

## Files touched

- `OSX/Icons/generate-menubar-icons.swift`
- `OSX/Assets.xcassets` (8 existing regenerated + `statushan`, `statuseng` added)
- `OSX/GureumAppDelegate.swift` (status item controller + click-menu methods)
- **Unchanged**: `OSX/Info.plist`, InputController/InputReceiver/GureumComposer,
  pbxproj (no new file/target).

## Risks

- **R1 (verify first):** a status item must actually display from this input-
  method agent process. Low risk (the process already shows UI), but confirmed
  on-device as the first build check.
- **R2:** `kTISNotifySelectedKeyboardInputSourceChanged` fires for every source
  change; the classifier's non-Gureum → hidden branch covers stray fires.
- **R3:** template tinting white-on-dark for the wide status image — same check as
  the asset-catalog clouds.

## Success criteria

- A wide, undistorted, pretty cloud appears in the menu bar via the status item;
  FILLED for Korean, OUTLINE for English, updating on Han/Eng toggle.
- Correct tint in light and dark menu bars.
- The system input-menu cloud (if shown) is the square letterbox cloud — not
  distorted.
- No input hot-path or pbxproj change.
