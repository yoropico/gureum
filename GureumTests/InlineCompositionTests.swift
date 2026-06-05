//
//  InlineCompositionTests.swift
//  OSXTests
//
//  Unit tests for the pure composition-mode policy (`classifyComposition`).
//  These tests intentionally avoid IMK/AppKit and a live `IMKTextInput`
//  client; the policy is exercised through the `ClientCapabilities`
//  abstraction only.
//

@testable import GureumCore
import XCTest

/// `ClientCapabilities`의 테스트용 스텁. 각 질의 표면을 생성 시점에 고정한다.
private struct StubCaps: ClientCapabilities {
    let alwaysMarked: Bool
    let showsMarked: Bool?
    let selectableRange: Bool
    let bundleID: String?
    let forcedMarked: [String]
    let chromiumFramework: Bool
    let learnedAppend: Bool

    init(alwaysMarked: Bool,
         showsMarked: Bool?,
         selectableRange: Bool,
         bundleID: String? = nil,
         forcedMarked: [String] = [],
         chromiumFramework: Bool = false,
         learnedAppend: Bool = false)
    {
        self.alwaysMarked = alwaysMarked
        self.showsMarked = showsMarked
        self.selectableRange = selectableRange
        self.bundleID = bundleID
        self.forcedMarked = forcedMarked
        self.chromiumFramework = chromiumFramework
        self.learnedAppend = learnedAppend
    }

    var alwaysMarkedGlobal: Bool { alwaysMarked }
    func showsComposingTextAsMarkedText() -> Bool? { showsMarked }
    func selectedRangeIsQueryable() -> Bool { selectableRange }
    var bundleIdentifier: String? { bundleID }
    var forcedMarkedBundleIDs: [String] { forcedMarked }
    func usesChromiumFrameworkTextStack() -> Bool { chromiumFramework }
    func learnedAppendOnly() -> Bool { learnedAppend }
}

class InlineCompositionTests: XCTestCase {
    func testAlwaysMarkedGlobalForcesMarked() {
        // 전역 강제 설정이 켜져 있으면 다른 필드와 무관하게 marked.
        let caps = StubCaps(alwaysMarked: true, showsMarked: false, selectableRange: true)
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testShowsMarkedTrueReturnsMarked() {
        let caps = StubCaps(alwaysMarked: false, showsMarked: true, selectableRange: true)
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testShowsMarkedFalseReturnsInline() {
        let caps = StubCaps(alwaysMarked: false, showsMarked: false, selectableRange: false)
        XCTAssertEqual(classifyComposition(caps), .inline)
    }

    func testUnknownShowsMarkedWithoutSelectableRangeReturnsMarked() {
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: false)
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testUnknownShowsMarkedWithSelectableRangeReturnsInline() {
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true)
        XCTAssertEqual(classifyComposition(caps), .inline)
    }

    // MARK: - P2: pure engine/blocklist helpers (DKST port, MIT)

    func testWebKitTextStackMatchesSafariAndWebKitBundles() {
        XCTAssertTrue(bundleIdentifierUsesWebKitTextStack("com.apple.Safari"))
        XCTAssertTrue(bundleIdentifierUsesWebKitTextStack("com.apple.WebKit.WebContent"))
        XCTAssertTrue(bundleIdentifierUsesWebKitTextStack("com.apple.mobilesafari"))
        XCTAssertTrue(bundleIdentifierUsesWebKitTextStack("com.apple.Safari.Helper"))
        // prefix는 점 경계를 요구한다: "com.apple.WebKit"으로 시작해도 다음이 점이 아니면 불일치.
        XCTAssertFalse(bundleIdentifierUsesWebKitTextStack("com.apple.WebKitten"))
        XCTAssertFalse(bundleIdentifierUsesWebKitTextStack("com.google.Chrome"))
        XCTAssertFalse(bundleIdentifierUsesWebKitTextStack(""))
    }

    func testChromiumMarkedPolicyMatchesKnownBrowsers() {
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("com.google.Chrome"))
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("com.google.Chrome.canary"))
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("com.microsoft.edgemac"))
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("com.brave.Browser"))
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("company.thebrowser.Browser")) // Arc
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("com.naver.Whale"))
        XCTAssertTrue(bundleIdentifierUsesChromiumMarkedTextPolicy("org.chromium.Chromium"))
        XCTAssertFalse(bundleIdentifierUsesChromiumMarkedTextPolicy("com.apple.Safari"))
        XCTAssertFalse(bundleIdentifierUsesChromiumMarkedTextPolicy(""))
    }

    func testForcedMarkedListMatchesCaseInsensitively() {
        let list = ["com.acme.Editor", "net.example.App"]
        XCTAssertTrue(bundleIdentifierMatchesForcedMarkedList("com.acme.Editor", list))
        XCTAssertTrue(bundleIdentifierMatchesForcedMarkedList("com.acme.editor", list)) // 대소문자 무시
        XCTAssertFalse(bundleIdentifierMatchesForcedMarkedList("com.acme.Other", list))
        XCTAssertFalse(bundleIdentifierMatchesForcedMarkedList("com.acme.Editor", []))
        XCTAssertFalse(bundleIdentifierMatchesForcedMarkedList("", list))
    }

    func testTerminalTextStackMatchesKnownTerminals() {
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("com.yoropico.bct")) // BCT (claude-terminal)
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("com.apple.Terminal"))
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("com.googlecode.iterm2"))
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("com.mitchellh.ghostty"))
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("net.kovidgoyal.kitty"))
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("org.alacritty"))
        XCTAssertTrue(bundleIdentifierUsesTerminalTextStack("com.github.wez.wezterm"))
        XCTAssertFalse(bundleIdentifierUsesTerminalTextStack("com.apple.Safari"))
        XCTAssertFalse(bundleIdentifierUsesTerminalTextStack(""))
    }

    func testAppendOnlyTextStackMatchesOfficeAndHancom() {
        XCTAssertTrue(bundleIdentifierUsesAppendOnlyTextStack("com.microsoft.Word"))
        XCTAssertTrue(bundleIdentifierUsesAppendOnlyTextStack("com.microsoft.Excel"))
        XCTAssertTrue(bundleIdentifierUsesAppendOnlyTextStack("com.microsoft.Powerpoint"))
        XCTAssertTrue(bundleIdentifierUsesAppendOnlyTextStack("com.microsoft.Outlook"))
        XCTAssertTrue(bundleIdentifierUsesAppendOnlyTextStack("com.haansoft.hwp"))
        // 점 경계 prefix: 같은 vendor라도 다른 앱은 잡지 않는다.
        XCTAssertFalse(bundleIdentifierUsesAppendOnlyTextStack("com.microsoft.VSCode"))
        XCTAssertFalse(bundleIdentifierUsesAppendOnlyTextStack("com.apple.Safari"))
        XCTAssertFalse(bundleIdentifierUsesAppendOnlyTextStack(""))
    }

    func testAppendOnlySeedBundleReturnsMarked() {
        // showsMarked nil + selectable true이면 기본 inline이지만, 시드 목록이면 marked.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.microsoft.Word")
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testLearnedAppendOnlyReturnsMarked() {
        // 런타임 학습으로 append-only로 판명된 클라이언트는 시드 목록에 없어도 marked.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.unknown.editor", learnedAppend: true)
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    // MARK: - P3: blocklist editor text <-> [String] normalization

    func testParseForcedMarkedListSplitsTrimsAndDropsBlanks() {
        let text = "com.acme.Editor\n  net.example.App  \n\n\tcom.foo.Bar\n   \n"
        XCTAssertEqual(parseForcedMarkedBundleIDList(text),
                       ["com.acme.Editor", "net.example.App", "com.foo.Bar"])
    }

    func testParseForcedMarkedListDedupesCaseInsensitivelyKeepingFirst() {
        let text = "com.acme.Editor\ncom.acme.editor\nnet.example.App\ncom.acme.EDITOR"
        XCTAssertEqual(parseForcedMarkedBundleIDList(text),
                       ["com.acme.Editor", "net.example.App"])
    }

    func testParseForcedMarkedListEmptyOrBlankYieldsEmpty() {
        XCTAssertEqual(parseForcedMarkedBundleIDList(""), [])
        XCTAssertEqual(parseForcedMarkedBundleIDList("   \n\t\n  "), [])
    }

    func testFormatForcedMarkedListJoinsWithNewlines() {
        XCTAssertEqual(formatForcedMarkedBundleIDList(["com.acme.Editor", "net.example.App"]),
                       "com.acme.Editor\nnet.example.App")
        XCTAssertEqual(formatForcedMarkedBundleIDList([]), "")
    }

    // MARK: - P2: classifyComposition engine/blocklist branches

    func testForcedMarkedBundleIDForcesMarked() {
        // showsMarked nil + selectable true이면 기본은 inline이지만, 강제 목록에 있으면 marked.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.acme.Editor", forcedMarked: ["com.acme.Editor"])
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testForcedMarkedOverridesWebKitInline() {
        // WebKit 번들이라도 사용자 강제 목록에 있으면 marked가 이긴다(강제 목록이 WebKit보다 우선).
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.apple.Safari", forcedMarked: ["com.apple.Safari"])
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testWebKitBundleReturnsInlineEvenWhenSelectedRangeUnqueryable() {
        // selectable=false면 기본 안전값은 marked지만, WebKit 판정이 그 앞 단계라 inline.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: false,
                            bundleID: "com.apple.Safari")
        XCTAssertEqual(classifyComposition(caps), .inline)
    }

    func testChromiumBundleReturnsMarked() {
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.google.Chrome")
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testTerminalBundleReturnsMarked() {
        // 터미널은 인라인 직접입력과 호환되지 않아(커밋 시 마지막 단어 중복) marked로 강제한다.
        // showsMarked nil + selectable true이면 기본 inline이지만 터미널이면 marked여야 한다.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.yoropico.bct")
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testTerminalAppleInlineSignalStillWins() {
        // 터미널이라도 Apple 신호가 명시적으로 inline(false)을 주면 그 신호를 신뢰한다(체인 2단계 우선).
        let caps = StubCaps(alwaysMarked: false, showsMarked: false, selectableRange: true,
                            bundleID: "com.googlecode.iterm2")
        XCTAssertEqual(classifyComposition(caps), .inline)
    }

    func testChromiumFrameworkScanReturnsMarked() {
        // 번들 prefix 목록에 없는 Electron 앱이라도 프레임워크 스캔이 true면 marked.
        let caps = StubCaps(alwaysMarked: false, showsMarked: nil, selectableRange: true,
                            bundleID: "com.unknown.electronapp", chromiumFramework: true)
        XCTAssertEqual(classifyComposition(caps), .marked)
    }

    func testAppleMarkedSignalBeatsChromiumPolicy() {
        // Apple 신호(showsMarked=false=inline)는 Chromium 판정보다 우선한다(체인 2단계).
        let caps = StubCaps(alwaysMarked: false, showsMarked: false, selectableRange: true,
                            bundleID: "com.google.Chrome")
        XCTAssertEqual(classifyComposition(caps), .inline)
    }
}

/// 인라인 렌더(Step 8)를 mock 클라이언트로 검증하는 통합 테스트.
/// 기존 한글 테스트와 동일한 입력 패턴(`inputKeys`)을 재사용한다.
class InlineRenderTests: XCTestCase {
    let app = ModerateApp()
    private var savedInlineEnabled = false

    override class func setUp() {
        Configuration.shared = Configuration(suiteName: "org.youknowone.Gureum.test")!
        super.setUp()
    }

    override class func tearDown() {
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        InputController.resetLearnedAppendOnlyCache()
        // 공유 Configuration은 실제 UserDefaults suite를 변경하므로 이전 값을 저장한다.
        savedInlineEnabled = Configuration.shared.inlineCompositionEnabled

        Configuration.shared.removePersistentDomain(forName: GureumTests.domainName)

        app.client.string = ""
        // 두벌식: "dkssud" => ㅇ ㅏ ㄴ ㄴ ㅕ ㅇ => "안녕"
        app.controller.setValue(GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag, client: app.client)
    }

    override func tearDown() {
        // suite를 더럽힌 채로 두지 않는다.
        Configuration.shared.inlineCompositionEnabled = savedInlineEnabled
        Configuration.shared.inlineCompositionEnabled = false
        InputController.resetLearnedAppendOnlyCache()
        super.tearDown()
    }

    /// 인라인 모드: 키 입력마다 직접 insertText가 발생하고 marked text는 전혀 호출되지 않는다.
    func testInlineModeProducesDirectInsertionsNoMarkedText() {
        Configuration.shared.inlineCompositionEnabled = true
        // classifyComposition은 NSTextView mock을 .marked로 분류할 수 있으므로,
        // 타이핑 직전에 컨트롤러 인스턴스에 직접 강제한다.
        app.controller.useMarkedText = false
        app.client.resetRecordedInsertions()
        app.client.resetRecordedMarkedTexts()

        app.inputKeys("dkssud") // ㅇ ㅏ ㄴ ㄴ ㅕ ㅇ

        let insertions = app.client.recordedInsertions()
        let markedTexts = app.client.recordedMarkedTexts()

        // 참고용: 실제 (string, range) 시퀀스를 테스트 로그에 출력한다.
        print("InlineRenderTests insertions: \(insertions)")

        // range를 존중하는 클라이언트(MockInputClient)에 적용되면 문서는 "안녕"이 된다.
        XCTAssertEqual("안녕", app.client.string, "document text mismatch: \(app.client.string)")
        XCTAssertEqual(0, markedTexts.count, "inline mode must NOT call setMarkedText, got: \(markedTexts)")
        XCTAssertEqual(6, insertions.count, "expected exactly one insert per keystroke, got: \(insertions)")

        // 텍스트 스토리지와 독립적으로 IME가 내보낸 insert 시퀀스 자체를 검증한다.
        // 각 항목은 (삽입 문자열, replacementRange) 쌍이며 순서대로 일치해야 한다.
        let notFoundRange = NSStringFromRange(NSRange(location: NSNotFound, length: 0))
        let firstReplace = NSStringFromRange(NSRange(location: 0, length: 1))
        let secondReplace = NSStringFromRange(NSRange(location: 1, length: 1))
        let expected: [(String, String)] = [
            ("ㅇ", notFoundRange),
            ("아", firstReplace),
            ("안", firstReplace),
            ("안ㄴ", firstReplace),
            ("녀", secondReplace),
            ("녕", secondReplace),
        ]
        XCTAssertEqual(expected.count, insertions.count, "insert count mismatch: \(insertions)")
        for (index, pair) in expected.enumerated() where index < insertions.count {
            let entry = insertions[index]
            XCTAssertEqual(pair.0, entry["string"], "insert[\(index)] string mismatch: \(entry)")
            XCTAssertEqual(pair.1, entry["range"], "insert[\(index)] range mismatch: \(entry)")
        }
    }

    /// 재현(Finder/일반 앱): 인라인으로 단어를 친 뒤 스페이스 커밋 시 마지막 음절이
    /// 중복되면 안 된다. space → action==.commit → cancelComposition()이 directRange를
    /// 먼저 비워, renderInline이 이미 삽입된 "녕"을 제자리 치환 못 하고 append → "안녕녕".
    func testInlineSpaceCommitDoesNotDuplicateLastSyllable() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        app.inputKeys("dkssud") // 안녕 (녕 인라인 조합 중)
        app.inputKey(.space)    // 커밋

        print("SpaceCommit doc: \(app.client.string)")
        XCTAssertFalse(app.client.string.contains("녕녕"), "space commit duplicated last syllable: \(app.client.string)")
        XCTAssertTrue(app.client.string.hasPrefix("안녕"), "doc should start with 안녕: \(app.client.string)")
    }

    /// 재현: 엔터 커밋 시에도 마지막 음절 중복 금지(.return 도 action==.commit).
    func testInlineEnterCommitDoesNotDuplicateLastSyllable() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        app.inputKeys("dkssud") // 안녕
        app.inputKey(.return)   // 엔터 커밋

        print("EnterCommit doc: \(app.client.string)")
        XCTAssertFalse(app.client.string.contains("녕녕"), "enter commit duplicated last syllable: \(app.client.string)")
        XCTAssertTrue(app.client.string.hasPrefix("안녕"), "doc should start with 안녕: \(app.client.string)")
    }

    /// ① fail-safe: 커밋 시점에 directRange 검증이 실패(위치 분실)해도 append로
    /// 중복을 만들면 안 된다. 실기(Finder/Word 등)에서 커밋 순간 directRangeIsCurrent가
    /// 실패하는 상황을 모사: 문서를 바꿔 directRange가 더 이상 "녕"을 담지 않게 한다.
    func testInlineCommitWithLostDirectRangeDoesNotAppend() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        app.inputKeys("dkssud") // 안녕 (녕 인라인 조합 중, directRange 추적)
        // 커밋 직전 문서를 교체 → directRange 위치 검증·backtrack 모두 실패하게 만든다.
        app.client.string = "ABC"
        app.client.setSelectedRange(NSRange(location: 3, length: 0))

        app.inputKey(.space) // 커밋

        print("LostRangeCommit doc: \(app.client.string)")
        // fail-safe면 위치를 못 찾을 때 append를 건너뛰므로 "녕"이 추가되지 않는다.
        XCTAssertFalse(app.client.string.contains("녕"),
                       "lost-range commit must not append the already-inline syllable: \(app.client.string)")
    }

    /// 인라인 조합 중 입력 모드 전환 시 진행 중인 음절이 중복되지 않아야 한다.
    /// (인라인으로 "안" 조합 → 모드 전환 → "안안" 회귀 방지)
    func testInlineModeChangeMidCompositionDoesNotDuplicate() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        app.inputKeys("dks") // ㅇ ㅏ ㄴ => "안" (커밋하지 않음)
        XCTAssertEqual("안", app.client.string, "inline composition should leave 안 in the document, got: \(app.client.string)")

        // 다른 입력 모드로 전환하면 진행 중인 인라인 조합이 커밋된다.
        app.controller.setValue(GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag, client: app.client)

        XCTAssertEqual("안", app.client.string, "mode change mid-composition must not duplicate the syllable, got: \(app.client.string)")
    }

    /// 인라인 조합 중 강제 커밋(deactivateServer가 트리거하는 경로) 시 진행 중인
    /// 음절이 중복되지 않아야 한다. (인라인으로 "안" 조합 → 강제 커밋 → "안안" 회귀 방지)
    ///
    /// deactivateServer(_:)를 직접 호출하지 않는 이유: 그 오버라이드는 인라인 인지
    /// 커밋(commitComposition)을 수행한 뒤 라이브 IMK super.deactivateServer(_:)를
    /// 호출하는데, 이 super는 XCTest 환경에서 IMK 서버/클라이언트 래퍼가 완전히
    /// 구성되지 않아 EXC_BAD_ACCESS(0x8)로 크래시한다(testIPMDServerClientWrapper와
    /// 동일 근본 원인). 따라서 deactivateServer가 트리거하는 인라인 인지 커밋 경로
    /// 자체(commitComposition → receiver.commitCompositionEvent)를 직접 구동해
    /// 불변식을 검증한다. 운영 코드의 deactivateServer는 영향받지 않는다.
    func testInlineForcedCommitMidCompositionDoesNotDuplicate() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        app.inputKeys("dks") // ㅇ ㅏ ㄴ => "안" (커밋하지 않음)
        XCTAssertEqual("안", app.client.string, "inline composition should leave 안 in the document, got: \(app.client.string)")

        // deactivateServer(_:)가 super 호출 직전에 수행하는 바로 그 커밋 경로.
        app.controller.commitComposition(app.client)

        XCTAssertEqual("안", app.client.string, "forced commit mid-composition must not duplicate the syllable, got: \(app.client.string)")
    }

    /// 킬스위치 OFF: marked 경로로 동작하며 인라인 결합 insert는 발생하지 않는다.
    func testKillSwitchOffFallsBackToMarkedPath() {
        Configuration.shared.inlineCompositionEnabled = false
        app.client.resetRecordedInsertions()
        app.client.resetRecordedMarkedTexts()

        app.inputKeys("dkssud") // ㅇ ㅏ ㄴ ㄴ ㅕ ㅇ

        let markedTexts = app.client.recordedMarkedTexts()
        let insertions = app.client.recordedInsertions()

        // marked 경로가 사용되었음이 핵심 불변식: setMarkedText가 호출되어야 한다.
        XCTAssertFalse(markedTexts.isEmpty, "marked path must run when kill-switch is OFF")

        // 인라인 경로가 동작하지 않았음을 결정적으로 확인한다: renderInline만이 만들어내는
        // (커밋+조합) 결합 insert("안ㄴ")가 절대 발생하지 않아야 한다. marked 경로는
        // 완성된 음절만 commit하므로 결합 문자열을 insertText로 내보내지 않는다.
        let combinedInlineStrings = insertions.compactMap { $0["string"] }
        XCTAssertFalse(combinedInlineStrings.contains("안ㄴ"),
                       "marked path must NOT emit the inline combined insert, got: \(insertions)")

        // 커밋 후 최종 문서 텍스트는 "안녕"으로 끝난다.
        app.inputKey(.space)
        XCTAssertTrue(app.client.string.hasSuffix("안녕"), "committed text should end with 안녕, got: \(app.client.string)")
    }

    func testLearnedAppendOnlyCacheRecordsAndResets() {
        InputController.resetLearnedAppendOnlyCache()
        XCTAssertFalse(InputController.isLearnedAppendOnly(bundleID: "com.test.x"))
        InputController.recordLearnedAppendOnly(bundleID: "com.test.x")
        XCTAssertTrue(InputController.isLearnedAppendOnly(bundleID: "com.test.x"))
        // 빈 번들 식별자는 기록하지 않는다.
        InputController.recordLearnedAppendOnly(bundleID: "")
        XCTAssertFalse(InputController.isLearnedAppendOnly(bundleID: ""))
        InputController.resetLearnedAppendOnlyCache()
        XCTAssertFalse(InputController.isLearnedAppendOnly(bundleID: "com.test.x"))
    }

    func testAppendOnlyClientIgnoresReplacementRange() {
        let client = MockInputClient()
        client.string = "ㅇ"
        client.setSelectedRange(NSRange(location: 1, length: 0))
        client.appendOnlyIgnoresReplacementRange = true
        // 제자리 치환을 요청해도 무시하고 끝에 append해야 한다(Word 모사).
        client.insertText("아", replacementRange: NSRange(location: 0, length: 1))
        XCTAssertEqual("ㅇ아", client.string, "append-only client must append, not replace: \(client.string)")
        XCTAssertEqual(2, client.selectedRange().location, "caret must land after the appended text")
    }

    func testInlineDemotesToMarkedWhenClientAppendsIgnoringRange() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false
        app.client.appendOnlyIgnoresReplacementRange = true
        app.client.resetRecordedMarkedTexts()

        // "dk" = ㅇ 그리고 ㅏ. 둘째 키가 첫 글자를 제자리 치환하려 하지만 append-only
        // 클라이언트가 무시하고 append → caret 착지 검증이 위반을 감지한다.
        app.inputKeys("dk")

        XCTAssertTrue(app.controller.useMarkedText,
                      "append-only client must be demoted to marked after the violating replace")
        let bundleID = app.client.bundleIdentifier() ?? ""
        XCTAssertTrue(InputController.isLearnedAppendOnly(bundleID: bundleID),
                      "violating client's bundle id must be learned")
        XCTAssertFalse(app.client.recordedMarkedTexts().isEmpty,
                       "demote must re-render the in-progress composition as marked text")
    }

    func testCursorMoveMidCompositionReanchorsInsteadOfReplacingStaleRange() {
        Configuration.shared.inlineCompositionEnabled = true
        app.controller.useMarkedText = false

        // 기존 텍스트 끝에서 조합을 시작한다.
        app.client.string = "XY"
        app.client.setSelectedRange(NSRange(location: 2, length: 0))
        app.inputKeys("d") // ㅇ → "XYㅇ", directRange=(2,1), expectedCaret=3

        // 사용자가 커서를 문서 맨 앞으로 옮긴다(클릭/화살표 모사).
        app.client.setSelectedRange(NSRange(location: 0, length: 0))
        app.client.resetRecordedInsertions()

        app.inputKeys("k") // ㅏ → "아"; action==.none. ②가 stale directRange(2,1)를 무효화.

        let insertions = app.client.recordedInsertions()
        XCTAssertFalse(insertions.isEmpty, "a keystroke after cursor move must produce an insertion")
        // 핵심: 옛 directRange(2,1) 제자리 치환이 아니라 NSNotFound(새 삽입)이어야 한다.
        let firstRange = insertions.first?["range"]
        XCTAssertEqual(NSStringFromRange(NSRange(location: NSNotFound, length: 0)), firstRange,
                       "after cursor move the keystroke must insert fresh (NSNotFound), not replace the stale range: \(insertions)")
    }
}
