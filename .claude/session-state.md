## Session state (devmode)
- Updated: 2026-06-03 (menu-bar cloud status item shipped: Apple `icloud` SF Symbol NSStatusItem
  + square-letterbox system icons; pushed to origin/main == 40e7b49)
- Goal: DONE & SHIPPED. History: notifications migration + han/eng fix (MERGED) -> fork
  README/CHANGELOG -> macOS cleanup & modernization (1.15.0, tagged) -> GitHub-based auto-updater
  (PR #3 MERGED) -> menu-bar icon simplify -> menu-bar cloud rework (status item) -> ALL pushed.
- Latest work (2026-06-03): menu-bar cloud rework. ROOT CAUSE of the user-reported squish: the TIS
  input-source menu-icon slot (Info.plist tsInputModeMenuIconFileKey) is a FIXED SQUARE, so a wide
  cloud (a brief 24x16 experiment) was aspect-distorted into it. Fix delivered in TWO layers:
  - Layer 1 (system input-menu icons, 8 imagesets): Apple SF Symbol `icloud`/`icloud.fill` rendered
    to a SQUARE template PNG (16/32), tight-bbox aspect-fit + LETTERBOXED -> undistorted (just shorter).
    Generator OSX/Icons/generate-menubar-icons.swift now renders the icloud symbol (icloud.fill=ko,
    icloud=en). Contents.json template-rendering-intent:template (unchanged).
  - Layer 2 (NEW NSStatusItem, OneDrive-style wide cloud): CloudStatusItemController in
    OSX/GureumAppDelegate.swift draws the `icloud` SF Symbol DIRECTLY (vector; status slot is
    width-flexible -> wide cloud undistorted). icloud.fill=Korean / icloud=English, pointSize **21**
    (15 read too small vs wifi/battery; 21 matches system icon height). Updated via distributed
    notification kTISNotifySelectedKeyboardInputSourceChanged; hidden when current source is non-Gureum;
    click shows a small menu (환경설정 / 정보). Pure `classify(inputSourceID:primaryLanguage:)` verified
    standalone 9/9. NO input hot-path (InputController/InputReceiver/Composer), Info.plist, or pbxproj
    change (code lives in existing GureumAppDelegate.swift; assets added to existing .xcassets).
  - Duplication: both clouds undistorted; to keep only the wide one the user turns off System Settings
    -> Keyboard -> "Show Input menu in menu bar" (no public API to toggle -> documented, not automated).
  - The brief statushan/statuseng wide-PNG + morphology-outline experiment was DROPPED (status item
    uses the SF Symbol directly). Hand-built bezier/circle-union clouds were rejected as less pretty.
  - Specs: docs/superpowers/specs/2026-06-03-menubar-cloud-square-redesign.md and
    docs/superpowers/specs/2026-06-03-menubar-statusitem-onedrive-cloud-design.md.
  - PENDING (user's eyes only; I cannot see the menu bar): confirm the status item actually appears
    from the IME agent process (R1) and the 21pt size looks right, in light & dark, on Han/Eng toggle.
- Repo state:
  - Local `main` == origin/main == **40e7b49** (synced, pushed). Only `main` branch.
  - This session's commits over prior origin (was 489923a): ef91411 + 80acb71 (specs), 8e25929 (cloud
    status item + square fix), 40e7b49 (status item 21pt). cfcb945 and earlier icon-iteration commits
    were already local; all now on origin/main.
  - Auto-updater (PR #3): OSX/Updater.swift + UpdateManager (GitHub Releases API, semver isNewer,
    validate(statusCode:)), OSX/Gureum-personal.entitlements. e2e PASSED. Tags 1.14.0->30f944d,
    1.15.0->66c79d1 pushed (1.16.0 e2e tag deleted).
  - Build (signed Release) SUCCEEDED each time; 45 tests, only known testIPMDServerClientWrapper fails
    (unsigned, pre-existing). Working tree clean (only `.claude/` churn).
- Installed build: /Library/Input Methods/Gureum.app = menu-bar-cloud build (code == 40e7b49),
  Apple Development signed (team G7J2LY4LP9, codesign VALID), 21pt icloud status item. Same signing
  identity across rebuilds -> Input Monitoring TCC and input-source registration persist.
- Mental model (for any follow-up):
  - App target OSX -> Gureum.app (org.youknowone.inputmethod.Gureum). Engine = OSXCore
    (GureumCore.framework). Each focused client gets its own IMKInputController -> InputReceiver
    -> GureumComposer; composer.inputMode (TIS id) and delegate (HangulComposer/RomanComposer)
    are kept in sync by the inputMode setter (GureumComposer.swift:150-175; sets
    Configuration.lastInputMode at :174).
  - Han/Eng switching is macOS-driven (enableCapslockToToggleInputMode=false): CapsLock uses #918
    TICapsLockLanguageSwitchCapable -> setValue drives the mode. InputController.swift:156 calls
    selectMode() -> moves the selected input source -> fires kTISNotifySelectedKeyboardInputSourceChanged
    (this is the signal the status item listens to; no hot-path edit needed).
  - Menu-bar icon mechanisms: (a) system input-source icon via Info.plist tsInputModeMenuIconFileKey =
    FIXED SQUARE slot (distorts non-square); (b) NSStatusItem = width-flexible slot (wide OK). OneDrive
    is pretty because it's a status-bar app (b), not an input-source icon (a).
- The han/eng bug & fix (PR #2, in main):
  - Root cause: (1) GureumComposer.init always started at lastRomanInputMode (qwerty); a missed setValue
    under activate/deactivate churn left the composer stuck English while the source showed Korean.
    (2) init set delegate=romanComposer AFTER inputMode, overwriting the Hangul delegate.
  - Fix: Configuration.lastInputMode tracks last actual mode; init seeds from it; init sets the default
    delegate BEFORE inputMode so the setter's delegate wins.
- Gotchas (still true; do NOT re-debug):
  1. sudo has no TTY via Bash/`!`; install via `osascript ... with administrator privileges`.
  2. Build: override CURRENT_PROJECT_VERSION=1.13 MARKETING_VERSION=1.13.2 (apple-generic casts
     CURRENT_PROJECT_VERSION to double; dotted git-describe breaks C). The build dirties
     OSX/Version.xcconfig -> `git checkout OSX/Version.xcconfig` and keep it OUT of diffs/commits.
  3. Empty ${VERSION} makes Xcode DROP CFBundleVersion -> IME won't register.
  4. Re-sign ad-hoc with OSX/Gureum.entitlements (+ get-task-allow) for sandbox/IOHID if going ad-hoc.
  5. Reinstalling an AD-HOC IME drops it from Input Sources + breaks Input Monitoring TCC (cdhash
     changes). The STABLE Apple Development signature (gotcha 11) avoids all this churn.
  6. `log` is a zsh builtin here -> use `/usr/bin/log show ...`.
  7. NSLog("...\(x)") logs the value as <private>; use os_log("%{public}@", str) for public values.
  8. 1 pre-existing unrelated test fails unsigned: GureumObjCTests.testIPMDServerClientWrapper.
  9. Deployment target 11.0; OSX/OSXCore have NO @available guards; Firebase/AnswersHelper/iOS removed.
 10. git hazard: ONE plain commit, no reset/amend/rebase, `git add` explicit paths only, restore
     OSX/Version.xcconfig if a build dirties it. Push to main needs FRESH user authorization each time
     (auto-mode classifier denies push without a per-instance OK).
 11. STABLE SIGNING: Identity "Apple Development: yoropico@gmail.com (K83K59TGLX)", team G7J2LY4LP9, in
     login keychain (needed Apple WWDR G3 intermediate imported). Build SIGNED with:
     `xcodebuild -project Gureum.xcodeproj -scheme OSX -configuration Release
     -derivedDataPath build/DerivedData-signed CURRENT_PROJECT_VERSION=1.13 MARKETING_VERSION=1.13.2
     DEVELOPMENT_TEAM=G7J2LY4LP9 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development"
     -allowProvisioningUpdates build`. Cert expires 2027-05-31. pbxproj still has upstream team
     9384JEL3M9 / "Developer ID Application" (do NOT commit team changes; override on cmdline only).
  Install: `killall Gureum; osascript -e "do shell script \"rm -rf '/Library/Input Methods/Gureum.app'
     && cp -R '<built>' '/Library/Input Methods/Gureum.app'\" with administrator privileges";
     open "/Library/Input Methods/Gureum.app"`.
- Auth: 1Password classic PAT "github-PAT(classic)" (user "claude") via `op item get ... --reveal`
  -> GH_TOKEN. But HTTPS push to origin currently works via cached osxkeychain creds (plain
  `git push origin main`). op desktop integration on (biometric, no `op signin`).
- Next / open:
  - Menu-bar cloud rework DONE & SHIPPED (origin/main == 40e7b49). Outstanding: user on-device confirm
    of the status item (R1) + 21pt size; if size/shape needs a tweak it's a 1-line pointSize change + rebuild.
  - Still optional: propose han/eng + SwiftIOKit fixes upstream (gureum/gureum); consider Sparkle.
  - MCP sync configured (.claude/devmode.json sessionProject=gureum). EXAM_API_KEY set ->
    PreCompact/SessionEnd hook AUTO-SAVE active. Manual MCP session_save still fine as a checkpoint.
