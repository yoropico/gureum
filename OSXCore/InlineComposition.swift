//
//  InlineComposition.swift
//  OSXCore
//
//  Ported from DKST (DINKIssTyle-IME-macOS).
//  MIT License. Copyright © 2025 DINKIssTyle.
//
//  This file is intentionally PURE: it must not import IMK/AppKit nor
//  produce any side effects, so the composition-mode policy can be unit
//  tested without a live `IMKTextInput` client.
//

import Foundation

/// 합성 중인 글자를 어떤 방식으로 클라이언트에 표시할지 나타내는 분류.
///
/// - `inline`: 클라이언트의 본문에 직접(인라인) 합성 결과를 반영한다.
/// - `marked`: 시스템이 제공하는 marked text(밑줄 표시)로 합성 결과를 보여 준다.
public enum CompositionMode: Equatable {
    case inline
    case marked
}

/// 합성 표시 방식을 결정하기 위해 필요한 클라이언트 정보를 추상화한 프로토콜.
///
/// 정책 결정 함수가 필요로 하는 모든 질의 표면을 이 프로토콜로 주입한다.
/// 라이브 `IMKTextInput` 클라이언트 없이도 정책을 테스트할 수 있도록
/// 이 프로토콜은 순수한 값 질의만 노출한다.
public protocol ClientCapabilities {
    /// 전역 "항상 marked text 사용" 설정 값.
    var alwaysMarkedGlobal: Bool { get }

    /// Apple이 제공하는 신호: 클라이언트가 합성 중인 글자를 marked text로
    /// 보여 주는지 여부.
    ///
    /// - Returns: `true`/`false`로 명확히 답할 수 있으면 해당 값을,
    ///   클라이언트가 이 API를 구현하지 않아 알 수 없으면 `nil`을 반환한다.
    ///
    /// - Important: `nil`은 "알 수 없음 / 미구현"을 뜻하며, 정책 체인이
    ///   다음 단계로 떨어질 수 있도록(fall through) 그대로 전달해야 한다.
    ///   이 함수에서 `nil`을 임의의 기본값으로 합쳐 버리면 안 된다.
    func showsComposingTextAsMarkedText() -> Bool?

    /// 클라이언트의 `selectedRange`를 인라인 합성에 쓸 수 있는지 여부.
    func selectedRangeIsQueryable() -> Bool

    /// 클라이언트(호스트 앱)의 번들 식별자.
    ///
    /// - Note: P1에서는 선언만 하고, P2(WebKit/Chromium/blocklist 판정)에서
    ///   소비한다.
    var bundleIdentifier: String? { get }
}

// MARK: - P2 hooks (RESERVED — DO NOT IMPLEMENT IN P1)
//
// 아래 항목들은 P2에서 결정 체인(`classifyComposition`)에 끼워 넣을 자리를
// 미리 예약해 둔 것이다. P1에서는 구현하지 않는다.
//
//  1. Blocklist match
//     `bundleIdentifier`가 알려진 비호환 앱 목록과 일치하면 강제로
//     특정 모드로 떨어뜨린다. (체인 최상단 근처에 위치)
//
//  2. WebKit → inline
//     WebKit 기반 호스트로 식별되면 인라인 합성을 우선한다.
//
//  3. Chromium → marked
//     Chromium 기반 호스트로 식별되면 marked text를 우선한다.
//
// 위 훅들은 모두 `bundleIdentifier`(및 P2에서 추가될 분류 정보)에 의존하며,
// `classifyComposition`(Step 3)이 도입되는 같은 파일의 결정 체인 안에서
// 호출될 예정이다.

// MARK: - Composition mode policy

/// 주어진 클라이언트 정보(`caps`)만으로 합성 표시 방식을 결정하는 순수 함수.
///
/// DKST의 `-[InputController shouldUseMarkedTextForClient:]`
/// (Sources/InputController.m:840)을 P1 범위로 포팅한 것이다.
/// IMK/AppKit에 접근하지 않으며 전역 상태(`Configuration.shared` 등)를
/// 내부에서 읽지 않는다. 모든 입력은 `caps`로만 들어온다.
///
/// 우선순위 체인(P1):
/// 1. `caps.alwaysMarkedGlobal`이면 → `.marked` (전역 강제).
/// 2. `caps.showsComposingTextAsMarkedText()`가 non-nil이면 즉시 반영:
///    `true → .marked`, `false → .inline` (Apple 신호 우선).
/// 3. (P2 훅 자리: blocklist → .marked, WebKit → .inline, Chromium → .marked)
/// 4. `caps.selectedRangeIsQueryable()`가 거짓이면 → `.marked` (안전 측면).
/// 5. 그 외 기본값 → `.inline`.
public func classifyComposition(_ caps: ClientCapabilities) -> CompositionMode {
    // 1. 전역 "항상 marked text" 설정.
    if caps.alwaysMarkedGlobal {
        return .marked
    }

    // 2. Apple 신호: non-nil이면 즉시 반영하고, nil이면 다음 단계로 떨어진다.
    if let showsMarked = caps.showsComposingTextAsMarkedText() {
        return showsMarked ? .marked : .inline
    }

    // 3. P2 hooks gap — 여기에 다음 판정들이 순서대로 들어간다 (P1에서는 미구현):
    //    blocklist match → .marked, WebKit → .inline, Chromium → .marked.

    // 4. selectedRange를 인라인 합성에 쓸 수 없으면 안전하게 marked.
    if !caps.selectedRangeIsQueryable() {
        return .marked
    }

    // 5. 기본값: 인라인 합성.
    return .inline
}
