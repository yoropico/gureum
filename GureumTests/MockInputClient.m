//
//  MockInputClient.m
//  OSXTestApp
//
//  Created by Jeong YunWon on 13/01/2019.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

#import "MockInputClient.h"

@implementation MockInputClient {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *_recordedInsertions;
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *_recordedMarkedTexts;
}

- (NSMutableArray<NSDictionary<NSString *, NSString *> *> *)mutableRecordedInsertions {
    if (_recordedInsertions == nil) {
        _recordedInsertions = [NSMutableArray array];
    }
    return _recordedInsertions;
}

- (NSMutableArray<NSDictionary<NSString *, NSString *> *> *)mutableRecordedMarkedTexts {
    if (_recordedMarkedTexts == nil) {
        _recordedMarkedTexts = [NSMutableArray array];
    }
    return _recordedMarkedTexts;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordedInsertions {
    return [[self mutableRecordedInsertions] copy];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordedMarkedTexts {
    return [[self mutableRecordedMarkedTexts] copy];
}

- (void)resetRecordedInsertions {
    [[self mutableRecordedInsertions] removeAllObjects];
}

- (void)resetRecordedMarkedTexts {
    [[self mutableRecordedMarkedTexts] removeAllObjects];
}

- (void)selectInputMode:(NSString *)modeIdentifier {
    NSLog(@"select input mode: %@", modeIdentifier);
}

- (NSInteger)length {
    return self.string.length;
}

- (NSString *)markedString {
    return [self.string substringWithRange:self.markedRange];
}

- (NSString *)selectedString {
    return [self.string substringWithRange:self.selectedRange];
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    // NSAssert(replacementRange.location == NSNotFound || replacementRange.length != 0, @"-");
    NSString *plainString = [string isKindOfClass:[NSAttributedString class]] ? [(NSAttributedString *)string string] : string;
    [[self mutableRecordedInsertions] addObject:@{
        @"string": plainString ?: @"",
        @"range": NSStringFromRange(replacementRange),
    }];

    // marked text가 활성화된 경우(marked 경로)에는 NSTextView의 내부 marked-region
    // 추적이 replacementRange를 정확히 처리하므로 기존 동작(super)을 그대로 유지한다.
    // 기존 한글/한자 테스트가 이 동작에 의존한다.
    if ([self hasMarkedText]) {
        [super insertText:string replacementRange:replacementRange];
        return;
    }

    // 인라인(직접 입력) 경로: 활성화된 marked region이 없으면 off-window /
    // non-first-responder NSTextView는 super를 통해 replacementRange를 적용하지
    // 않고 단순히 텍스트를 누적한다. range를 존중하는 실제 클라이언트를 충실히
    // 모사하기 위해 text storage에 직접 대체를 적용한다.
    NSString *insertion = plainString ?: @"";
    NSRange target = replacementRange;
    if (target.location == NSNotFound) {
        // 현재 선택(삽입 지점 또는 선택 영역 대체)에 삽입한다.
        target = self.selectedRange;
        if (target.location == NSNotFound || NSMaxRange(target) > self.textStorage.length) {
            target = NSMakeRange(self.textStorage.length, 0);
        }
    } else if (NSMaxRange(target) > self.textStorage.length) {
        // 방어적 처리: 범위가 현재 저장소를 벗어나면 끝에 삽입한다.
        target = NSMakeRange(self.textStorage.length, 0);
    }
    [self.textStorage replaceCharactersInRange:target withString:insertion];
    NSRange newSelection = NSMakeRange(target.location + insertion.length, 0);
    [self setSelectedRange:newSelection];
}

- (void)setMarkedText:(id)string selectionRange:(NSRange)selectionRange replacementRange:(NSRange)replacementRange {
    NSString *recorded = [string isKindOfClass:[NSAttributedString class]] ? [(NSAttributedString *)string string] : string;
    [[self mutableRecordedMarkedTexts] addObject:@{
        @"string": recorded ?: @"",
        @"selectionRange": NSStringFromRange(selectionRange),
        @"replacementRange": NSStringFromRange(replacementRange),
    }];
    NSRange selected = NSMakeRange(replacementRange.location + selectionRange.location, selectionRange.length);
    [self setMarkedText:string selectedRange:selected replacementRange:replacementRange];
    [self setSelectedRange:selected];

//    NSRange s = self.selectedRange;
//    NSRange m = self.markedRange;
//    NSAssert(selected.location == s.location && selected.length == s.length, @"");
//    NSAssert(selected.location == m.location && selected.length == m.length, @"");
}

// NSTextInputClient 셀렉터(selectedRange)를 직접 호출하는 marked 경로(production
// updateComposition)도 동일한 recordedMarkedTexts 배열에 기록되도록 오버라이드한다.
// 위의 IMK 스타일 selectionRange 오버라이드와 동일한 dict 형태를 사용하되
// selectionRange -> selectedRange 로 적용한다. super를 호출하여 NSTextView의
// marked region 갱신은 그대로 유지한다(기존 한글/한자 marked-mode 테스트가 의존).
- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
    NSString *recorded = [string isKindOfClass:[NSAttributedString class]] ? [(NSAttributedString *)string string] : string;
    [[self mutableRecordedMarkedTexts] addObject:@{
        @"string": recorded ?: @"",
        @"selectionRange": NSStringFromRange(selectedRange),
        @"replacementRange": NSStringFromRange(replacementRange),
    }];
    [super setMarkedText:string selectedRange:selectedRange replacementRange:replacementRange];
}

- (void)overrideKeyboardWithKeyboardNamed:(NSString *)keyboardUniqueName {
    // do nothing
}

- (NSString *)bundleIdentifier {
    return [NSBundle mainBundle].bundleIdentifier;
}

@end
