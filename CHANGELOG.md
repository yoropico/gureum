# 변경 이력

이 프로젝트의 주요 변경 사항을 기록합니다. 형식은
[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
[유의적 버전](https://semver.org/lang/ko/)을 사용합니다.

이 저장소는 [gureum/gureum](https://github.com/gureum/gureum)의 포크입니다.
아래 항목은 upstream 대비 이 포크에서 추가된 변경 사항이며, upstream 자체의
변경 이력은 원본 저장소를 참고해 주세요.

## [Unreleased]

견고성(robustness) 개선과 환경설정 호스팅 정리 릴리스입니다. 입력 동작에는 변화가 없습니다.

### 바뀜 (Changed)

- **환경설정을 앱 내장 윈도로 단일화 (macOS 26 대비).** 메뉴의 `환경설정...`은 이미 `Configuration.storyboard` 기반 앱 내장 윈도(`PreferencePaneViewController.viewFromNib()`)로 설정 UI를 직접 띄우고 있었으나, 앱 쪽에 deprecated된 System Settings `.prefPane` 호스팅(`NSPreferencePane`/`NSPrefPaneBundle`) 경로가 죽은 코드로 남아 있었습니다. macOS 13+ System Settings에서 서드파티 prefPane 호스팅이 취약하고 macOS 26에서 더 불안정할 수 있어, 앱에서 이 경로를 제거하고 nib 호스팅만 사용하도록 정리했습니다. (`OSX/ConfigurationWindow.swift`) 별도의 레거시 `Preferences.prefPane` 타깃 자체는 호환을 위해 유지합니다.

### 고침 (Fixed)

- **한자·이모지 검색 리소스 로딩 시 크래시 가능성 제거.** `FuseSearchSource`가 번들 리소스(`hanjar`/`emoji`/`emoji_ko`)를 `try!`로 읽어, 파일이 없거나 UTF-8로 읽히지 않으면 즉시 크래시했습니다. 이제 읽기 실패 시 빈 소스로 시작하고 오류를 로그로 남깁니다. 또한 `"설명:완성"` 형식이 아닌(콜론 없는) 줄을 만나면 첨자 접근에서 크래시하던 문제도 해당 줄을 건너뛰도록 고쳤습니다. (`OSXCore/SearchPool.swift`)

### 제거 (Removed)

- **죽은 코드 정리.** `UpdateManager`의 주석 처리된 `responseJSON` 디버그 블록과, 프로퍼티명과 동일해 컴파일러가 자동 합성하던 불필요한 `UpdateInfo.CodingKeys` 보일러플레이트를 제거했습니다. (`OSX/UpdateManager.swift`)

## [1.15.0] - 2026-06-01

코드 정리와 현대화 릴리스입니다. 죽은 코드와 무거운 의존성을 크게 줄였습니다.
최소 macOS 버전 상향을 제외하면 입력 동작에는 변화가 없습니다.

### 바뀜 (Changed)

- **최소 macOS 버전 상향: 10.13 → 11.0 (Big Sur).** macOS 11.0 미만에서는 더 이상 동작하지 않습니다. 이에 맞춰 소스의 macOS 10.14 / 10.15 / 11.0 `@available` 가드를 모두 걷어냈습니다. (Preferences의 macOS 13 가드는 유지)

### 제거 (Removed)

- **Firebase Crashlytics 전체 제거.** `firebase-ios-sdk` SPM 의존성, `FirebaseCrashlytics` 링크, "Run Crashlytics" 빌드 페이즈, 번들되던 `GoogleService-Info.plist`, `FirebaseApp.configure()` 호출을 모두 제거했습니다. 크래시 리포트가 이 포크가 아닌 upstream 작성자의 Firebase 프로젝트로만 전송되던 것을 없애면서, gRPC·BoringSSL·protobuf 등 약 16개의 transitive SPM 패키지가 함께 사라졌습니다(남은 의존성: MASShortcut·Fuse·Alamofire·SwiftUp). 크래시 수집을 위해 켜 두던 `NSApplicationCrashOnExceptions` 등록도 함께 제거했습니다.
- **죽은 분석 코드(`AnswersHelper`) 제거.** Fabric/Answers SDK가 빠진 뒤 본문이 전부 주석 처리되어 아무 동작도 하지 않던 셸과 모든 호출부를 제거했습니다.
- **미사용 iOS 서브시스템 제거.** 어떤 활성 빌드(Gureum.xcodeproj·Makefile·CI 모두 macOS 전용)에서도 참조되지 않고, 2020년에 종료된 Fabric/Crashlytics SDK를 import하던 iOS 소스 일체(`iOS/`, `iOSApp/`, `iOSShared/`, `iOSTests/`, `iOSTheme/`)와 독립 `iOS.xcodeproj`를 제거했습니다(약 1만 줄).

## [1.14.0] - 2026-06-01

upstream `1.13.2`를 기반으로 한 첫 포크 릴리스입니다.

### 고침 (Fixed)

- **한글 입력이 영어로 고착되는 문제** ([#2](https://github.com/yoropico/gureum/pull/2)) — Edge/Chromium 등 포커스가 빠르게 바뀌는(activate/deactivate가 잦은) 앱에서, 입력 소스 표시는 한글인데 실제로는 영어가 입력되던 문제를 고쳤습니다.
  - 원인 ① `GureumComposer`가 새 입력 세션을 항상 마지막 *로마자* 모드(쿼티)로 시작해, 시스템의 `setValue`(한/영 전환) 호출을 놓치면 한글 표시 상태인데도 영어로 고착되었습니다.
  - 원인 ② 초기화 시 `inputMode`를 설정한 뒤 `delegate`를 로마자 조합기로 덮어써, 한글 모드인데 영어가 입력되었습니다.
  - 수정: `Configuration`에 `lastInputMode`(한/영 무관, 마지막 실제 입력 모드)를 추가하고, `GureumComposer.init`이 이 값을 초기 모드로 이어받도록 했습니다. 또한 기본 `delegate`를 `inputMode` 설정보다 *먼저* 두어, `inputMode` setter가 정한 조합기가 항상 마지막에 적용되게 했습니다.
- **Preferences 타겟 빌드 실패** ([#1](https://github.com/yoropico/gureum/pull/1)) — Xcode의 explicitly-built modules 환경에서 `PreferenceViewController`가 `SwiftIOKit` 대신 `IOKit.hid`를 import 하도록 바꿔 빌드 오류를 해결했습니다.

### 바뀜 (Changed)

- **알림 시스템 현대화** ([#1](https://github.com/yoropico/gureum/pull/1)) — deprecated된 `NSUserNotification` / `NSUserNotificationCenter`를 최신 `UserNotifications` 프레임워크로 마이그레이션했습니다. (`OSX/GureumAppDelegate.swift`, `OSX/UpdateManager.swift`, 관련 테스트)

[Unreleased]: https://github.com/yoropico/gureum/compare/1.15.0...main
[1.15.0]: https://github.com/yoropico/gureum/compare/1.14.0...1.15.0
[1.14.0]: https://github.com/yoropico/gureum/compare/1.13.2...1.14.0
