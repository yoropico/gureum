//
//  Updater.swift
//  OSX
//
//  Downloads a GitHub Release .zip, verifies its code signature, and installs
//  it to /Library/Input Methods via a single administrator prompt. Falls back
//  to opening the release page when the privileged install is unavailable
//  (e.g. a sandboxed build).
//

import Alamofire
import AppKit
import Foundation

enum UpdaterError: Error {
    case noAsset
    case download
    case unzip
    case verification
    case install
    case sandboxed
    case cancelled
}

final class Updater {
    static let shared = Updater()

    private let installPath = "/Library/Input Methods/bomi-input.app"
    private let inputMethodsDir = "/Library/Input Methods"
    private let expectedTeamIdentifier = "G7J2LY4LP9"
    private let lsregisterPath =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    /// 업데이트 zip을 받아 검증하고 설치한다. completion은 메인 스레드에서 호출된다.
    func performUpdate(info: UpdateManager.VersionInfo,
                       completion: @escaping (Result<Void, UpdaterError>) -> Void)
    {
        let downloadString = info.update.url
        guard let downloadURL = URL(string: downloadString), downloadString.hasSuffix(".zip") else {
            openReleasePage(info)
            return finish(completion, .failure(.noAsset))
        }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bomi-inputUpdate-\(UUID().uuidString)")
        let destination: DownloadRequest.Destination = { _, _ in
            try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
            return (workDir.appendingPathComponent("bomi-input.zip"), [.removePreviousFile, .createIntermediateDirectories])
        }

        AF.download(downloadURL, to: destination).validate().response { [weak self] response in
            guard let self = self else { return }
            guard response.error == nil, let zipURL = response.fileURL else {
                try? FileManager.default.removeItem(at: workDir)
                return self.finish(completion, .failure(.download))
            }
            self.installFromZip(zipURL, workDir: workDir, info: info, completion: completion)
        }
    }

    private func installFromZip(_ zipURL: URL,
                                workDir: URL,
                                info: UpdateManager.VersionInfo,
                                completion: @escaping (Result<Void, UpdaterError>) -> Void)
    {
        let extractDir = workDir.appendingPathComponent("extracted")
        guard run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractDir.path]).status == 0,
              let appURL = findApp(in: extractDir)
        else {
            try? FileManager.default.removeItem(at: workDir)
            return finish(completion, .failure(.unzip))
        }

        guard run("/usr/bin/codesign", ["--verify", "--strict", appURL.path]).status == 0,
              teamIdentifier(of: appURL) == expectedTeamIdentifier
        else {
            try? FileManager.default.removeItem(at: workDir)
            return finish(completion, .failure(.verification))
        }

        // 셸 명령에 zip이 정한 번들 이름이 끼어드는 것을 막기 위해, 검증된 앱을
        // 통제된 고정 경로(UUID 디렉터리 + 고정 이름)로 옮긴 뒤 그 경로로 설치한다.
        let safeAppURL = workDir.appendingPathComponent("bomi-input.app")
        try? FileManager.default.removeItem(at: safeAppURL)
        do {
            try FileManager.default.moveItem(at: appURL, to: safeAppURL)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            return finish(completion, .failure(.install))
        }

        installWithPrivileges(appURL: safeAppURL, workDir: workDir, info: info, completion: completion)
    }

    private func installWithPrivileges(appURL: URL,
                                       workDir: URL,
                                       info: UpdateManager.VersionInfo,
                                       completion: @escaping (Result<Void, UpdaterError>) -> Void)
    {
        let src = appURL.path
        // 셸 경로는 작은따옴표로 감싼다(AppleScript 문자열은 큰따옴표). src는 통제된
        // 고정 경로이므로 주입 위험이 없다.
        let shell = "rm -rf '\(installPath)' && cp -R '\(src)' '\(inputMethodsDir)/' && "
            + "/usr/bin/killall -TERM bomi-input 2>/dev/null; '\(lsregisterPath)' -f '\(installPath)'; true"
        let source = "do shell script \"\(shell)\" with administrator privileges"

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            var errorDict: NSDictionary?
            let script = NSAppleScript(source: source)
            _ = script?.executeAndReturnError(&errorDict)
            try? FileManager.default.removeItem(at: workDir)
            if let error = errorDict {
                let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
                if code == -128 { // userCanceledErr
                    return self.finish(completion, .failure(.cancelled))
                }
                // 샌드박스 등으로 권한 실행이 막힌 경우: 릴리스 페이지로 폴백.
                self.openReleasePage(info)
                return self.finish(completion, .failure(.sandboxed))
            }
            self.finish(completion, .success(()))
        }
    }

    // MARK: - Helpers

    private func findApp(in directory: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.first(where: { $0.pathExtension == "app" })
    }

    /// codesign -dvv 출력을 파싱해 TeamIdentifier를 얻는다.
    private func teamIdentifier(of appURL: URL) -> String? {
        let result = run("/usr/bin/codesign", ["-dvv", appURL.path])
        // codesign는 -dvv 정보를 stderr로 출력한다.
        for line in result.stderr.split(separator: "\n") {
            if line.hasPrefix("TeamIdentifier=") {
                return String(line.dropFirst("TeamIdentifier=".count))
            }
        }
        return nil
    }

    private func openReleasePage(_ info: UpdateManager.VersionInfo) {
        let urlString = info.pageURL ?? info.update.url
        if let url = URL(string: urlString) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
    }

    private func run(_ launchPath: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return (-1, "", "\(error)")
        }
        // 두 파이프를 동시에 비워, 한쪽 버퍼가 차서 프로세스가 멈추는 교착을 막는다.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "org.youknowone.gureum.updater.pipe", attributes: .concurrent)
        queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }
        group.wait()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(data: outData, encoding: .utf8) ?? "",
                String(data: errData, encoding: .utf8) ?? "")
    }

    private func finish(_ completion: @escaping (Result<Void, UpdaterError>) -> Void,
                        _ result: Result<Void, UpdaterError>)
    {
        DispatchQueue.main.async { completion(result) }
    }
}
