# Design: Gureum status-bar cloud indicator (Apple `icloud` SF Symbol)

Date: 2026-06-03
Status: Built & installed (final design below). Builds on
`2026-06-03-menubar-cloud-square-redesign.md`. Scope: macOS app target (`OSX`) —
asset catalog + generator + `GureumAppDelegate.swift`. No Info.plist, no input
hot-path (InputController/InputReceiver/Composer) change, no pbxproj change.

## Why

The menu-bar input-source icon slot (`tsInputModeMenuIconFileKey`) is a FIXED
SQUARE, so a wide cloud is aspect-distorted into it (the original squish). The
OneDrive menu-bar cloud avoids this only because OneDrive is a **status-bar app
(NSStatusItem)** — that slot is **width-flexible**, so a wide image shows
undistorted. The user wanted that look. So we add Gureum's own NSStatusItem with
a wide cloud, while ALSO fixing the system input-source icon so it is not
distorted either way.

We do NOT hand-roll the cloud art or embed Microsoft's OneDrive logo (trademark).
The cloud is Apple's **`icloud` SF Symbol** family — `icloud.fill` (Korean) and
`icloud` (English) — chosen by the user over the plainer `cloud` family. Drawn
directly as a vector in the status item it is crisp at any size and auto-tints to
the menu-bar appearance.

## Two layers

### Layer 1 — system input-menu icons (8 imagesets): square letterbox cloud
The 8 imagesets (`eng, qwerty, han, han2, han3, han390, han3final, hanroman`)
stay SQUARE (matches the square slot) and hold the `icloud` SF Symbol rendered to
a template PNG, aspect-fit (tight bounds) and **letterboxed** in the square —
undistorted, just a bit shorter than the tile. Fixes the original bug for users
who keep the system input menu visible. (`icloud.fill` for ko imagesets, `icloud`
for en imagesets.)

### Layer 2 — NSStatusItem: wide `icloud` cloud (the feature)
- **Created in** `GureumAppDelegate.applicationDidFinishLaunching`. The IME is a
  persistent agent process (it already shows windows/About/Preferences and runs
  `NSApplication.shared.run()`), so a status item lives for the process lifetime.
- **Image**: `NSImage(systemSymbolName: "icloud.fill" | "icloud")` with a
  `SymbolConfiguration(pointSize: 15, weight: .regular)`, `isTemplate = true`,
  assigned to `item.button?.image`. **No PNG asset** — the symbol is drawn
  directly (vector), so it is undistorted in the width-flexible status slot and
  needs nothing from the asset catalog.
- **Update signal**: observe the distributed notification
  `kTISNotifySelectedKeyboardInputSourceChanged`. On each change (and at launch)
  read `TISCopyCurrentKeyboardInputSource()` and classify. **No edit to the input
  hot path** — Gureum already calls `selectMode()` (InputController.swift:156),
  which moves the selected input source, which fires this notification.
- **Visibility**: shown only when the current input source is a Gureum source;
  hidden when another IME is active (avoids a confusing stray cloud).
- **Click**: a small NSMenu (환경설정… / 구름 입력기 정보…) wired to methods on
  the controller (the existing `menu` outlet targets InputController via the
  responder chain, which a status item can't reach — so a dedicated menu).

## Classifier (the one unit-tested piece)

Pure function on `CloudStatusItemController`, no AppKit state:

```
enum CloudState { case korean, english, hidden }
static func classify(inputSourceID id: String, primaryLanguage lang: String?) -> CloudState {
    let prefix = "org.youknowone.inputmethod.Gureum."
    guard id.hasPrefix(prefix) else { return .hidden }         // non-Gureum -> hide
    if let lang = lang { return lang == "ko" ? .korean : .english }
    let romanModes: Set<String> = ["qwerty", "colemak", "dvorak"]   // fallback by mode id
    return romanModes.contains(String(id.dropFirst(prefix.count))) ? .english : .korean
}
```

Matches the system's own ko/en icon choice (Info.plist `TISIntendedLanguage`).
Verified by a standalone Swift script (9/9 cases) — the XCTest target would
require a pbxproj edit, which session gotcha #10 says to avoid, so the pure
function is exercised by a throwaway `swift` run instead.

## Duplication (two clouds)

Both clouds are undistorted. A user who wants ONLY the wide status cloud turns off
System Settings → Keyboard → "Show Input menu in menu bar". There is no public API
to toggle that, so we **document it** rather than automate. Default: both show.

## Assets / generation

`OSX/Icons/generate-menubar-icons.swift` renders the `icloud` / `icloud.fill` SF
Symbol to template PNGs (black + alpha; `Contents.json`
`template-rendering-intent: template`), tight-bounds aspect-fit and letterboxed in
a SQUARE tile, 16×16 / 32×32, for the 8 system imagesets. The status item draws
the symbol directly, so it needs no generated asset.

## Files touched

- `OSX/Icons/generate-menubar-icons.swift` (icloud SF Symbol → square letterbox)
- `OSX/Assets.xcassets` (8 imagesets regenerated; the brief experiment's
  `statushan`/`statuseng` imagesets were removed — the status item uses the symbol
  directly)
- `OSX/GureumAppDelegate.swift` (`CloudStatusItemController` + click-menu methods)
- **Unchanged**: `OSX/Info.plist`, InputController/InputReceiver/GureumComposer,
  pbxproj (no new file/target).

## Verification

- BUILD SUCCEEDED (signed Release, session gotcha #11; `OSX/Version.xcconfig`
  restored out of the diff). Installed to `/Library/Input Methods/`, codesign
  VALID, process relaunched.
- Classifier: 9/9 standalone cases pass.
- On-device (R1 first): the status item appears from the IME agent process; the
  wide `icloud` cloud shows filled for Korean / outline for English, toggles on
  Han/Eng, tints correctly in light & dark; the system input-menu cloud is the
  square letterbox `icloud` (not distorted).

## Success criteria

- A wide, undistorted `icloud` cloud appears in the menu bar via the status item;
  FILLED (Korean) / OUTLINE (English), updating on Han/Eng toggle, correctly
  tinted in light & dark.
- The system input-menu cloud (if shown) is the square letterbox `icloud` — not
  distorted.
- No input hot-path or pbxproj change.
