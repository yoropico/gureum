//
//  MockInputClient.h
//  OSXTestApp
//
//  Created by Jeong YunWon on 13/01/2019.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

@import Cocoa;
@import InputMethodKit;

NS_ASSUME_NONNULL_BEGIN

@interface MockInputClient : NSTextView<IMKTextInput, IMKUnicodeTextInput>

- (NSString *)markedString;
- (NSString *)selectedString;

// Ordered recording of insertText:replacementRange: calls. Each entry is an
// NSDictionary of the form @{@"string": <NSString>, @"range": NSStringFromRange(replacementRange)}.
- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordedInsertions;
// Ordered recording of setMarkedText:selectionRange:replacementRange: calls. Each entry is an
// NSDictionary of the form @{@"string": <NSString>, @"selectionRange": NSStringFromRange(selectionRange), @"replacementRange": NSStringFromRange(replacementRange)}.
- (NSArray<NSDictionary<NSString *, NSString *> *> *)recordedMarkedTexts;
- (void)resetRecordedInsertions;
- (void)resetRecordedMarkedTexts;

@end

NS_ASSUME_NONNULL_END
