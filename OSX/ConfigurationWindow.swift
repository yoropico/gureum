//
//  ConfigurationWindow.swift
//  OSX
//
//  Created by Jeong YunWon on 2019/11/03.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation

final class ConfiguraionWindowController: NSWindowController {}

final class PreferencePaneViewController: NSViewController {
    func viewForFailure() -> NSView {
        let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
        let label = NSTextView(frame: rect)
        label.isEditable = false
        label.string = "환경설정 GUI 읽기에 실패했습니다. 버그 리포트를 남겨주세요.\n\nhttps://github.com/gureum/gureum/issues"
        let view = NSView(frame: rect)
        view.addSubview(label)
        return view
    }

    func viewFromNib() -> NSView {
        var topLevelObjects: NSArray?
        let succeed = Bundle.main.loadNibNamed("Preferences", owner: self, topLevelObjects: &topLevelObjects)
        guard let nibObjects = topLevelObjects, succeed else {
            NSLog("Preferences nib loading failed.")
            return viewForFailure()
        }
        guard let vc = nibObjects.filter({
            ($0 as! NSObject).className == "PreferenceViewController"
        }).first as? PreferenceViewController else {
            NSLog("Preferences lookup failed.")
            return viewForFailure()
        }
        return vc.view
    }

    override func loadView() {
        // 환경설정 UI는 앱 프로세스 안에서 직접 nib으로 띄운다.
        // 예전에는 System Settings의 .prefPane 호스팅을 거쳤으나, macOS 13+
        // System Settings에서 서드파티 prefPane 호스팅이 취약해 앱 내장 방식만 쓴다.
        view = viewFromNib()
    }
}
