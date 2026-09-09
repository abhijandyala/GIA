import AppKit
import AVFoundation
import Foundation
import Speech

enum HostWakeLog {
    static let url: URL = {
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: logs,
            withIntermediateDirectories: true
        )
        return logs.appendingPathComponent("GIAMacWake.log")
    }()

    static func write(_ message: String) {
        let line = message + "\n"
        fputs(line, stderr)
        fflush(stderr)
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url)
        }
    }
}

enum HostWakeEnv {
    static let fileURL: URL = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/GIAMacWake",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("env")
    }()

    static func load() -> [String: String] {
        guard
            let text = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            return [:]
        }
        var values: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            values[String(parts[0])] = String(parts[1])
        }
        return values
    }
}

@main
enum GIAMacWake {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        _ = app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let listener = HostWakeListener()
    private var statusWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.regular)
        showStatus(
            "Allow Microphone and Speech Recognition if macOS asks, then say Hey GIA."
        )
        NSApp.activate(ignoringOtherApps: true)
        HostWakeLog.write("GIA Mac Wake is starting.")
        HostWakeLog.write("Status window count: \(NSApp.windows.count)")
        Task.detached { [listener = listener] in
            await listener.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    private func showStatus(_ text: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 128),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GIA Mac Wake"
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        window.isReleasedWhenClosed = false
        window.center()

        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: 20, y: 24, width: 420, height: 80)
        label.font = .systemFont(ofSize: 14)
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil)
        statusWindow = window
    }
}

final class HostWakeListener: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastWakeAt: TimeInterval = 0
    private var lastHeard = ""
    private var isTapInstalled = false
    private var isRestarting = false
    private let cooldown: TimeInterval = 6
    private let simulatorID: String
    private let developerDir: String?

    init() {
        let processEnv = ProcessInfo.processInfo.environment
        let fileEnv = HostWakeEnv.load()
        simulatorID =
            processEnv["GIA_SIMULATOR_UDID"]
            ?? fileEnv["GIA_SIMULATOR_UDID"]
            ?? "booted"
        developerDir =
            processEnv["DEVELOPER_DIR"]
            ?? fileEnv["DEVELOPER_DIR"]
    }

    func start() async {
        HostWakeLog.write("Listener task started.")

        let microphoneOK = await requestMicrophone()
        guard microphoneOK else {
            HostWakeLog.write(
                "Microphone access is off. Allow it for GIA Mac Wake in System Settings, then run this again."
            )
            return
        }

        let speechOK = await requestSpeech()
        guard speechOK else {
            HostWakeLog.write(
                "Speech recognition is off. Allow it for GIA Mac Wake in System Settings, then run this again."
            )
            return
        }

        HostWakeLog.write("Creating speech recognizer.")
        let recognizer =
            SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
            ?? SFSpeechRecognizer()
        speechRecognizer = recognizer
        HostWakeLog.write("Speech recognizer is ready.")

        do {
            try beginListening()
            HostWakeLog.write(
                "Listening on this Mac for Hey GIA. Keep Simulator open with GIA running."
            )
        } catch {
            HostWakeLog.write(
                "Could not start the Mac microphone: \(error.localizedDescription)"
            )
        }
    }

    private func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                AVAudioApplication.requestRecordPermission { granted in
                    HostWakeLog.write(
                        granted
                            ? "Microphone access is on."
                            : "Microphone access is off."
                    )
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestSpeech() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                SFSpeechRecognizer.requestAuthorization { status in
                    HostWakeLog.write(
                        status == .authorized
                            ? "Speech recognition is on."
                            : "Speech recognition is off."
                    )
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    private func beginListening() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.addsPunctuation = false
        request.requiresOnDeviceRecognition = false
        request.contextualStrings = HostWakePhrase.contextualStrings
        recognitionRequest = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) {
            [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isTapInstalled = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) {
            [weak self] result, error in
            guard let self else { return }
            if let transcript = result?.bestTranscription.formattedString {
                self.handle(transcript: transcript)
            }
            if result?.isFinal == true || error != nil {
                self.restartListeningSoon()
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handle(transcript: String) {
        let trimmed = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }
        if trimmed != lastHeard {
            lastHeard = trimmed
            HostWakeLog.write("Heard: \(trimmed)")
        }
        guard HostWakePhrase.containsWakePhrase(trimmed) else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWakeAt >= cooldown else { return }
        lastWakeAt = now
        HostWakeLog.write("Heard Hey GIA. Starting GIA in Simulator.")
        triggerSimulator()
    }

    private func restartListeningSoon() {
        guard !isRestarting else { return }
        isRestarting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.isRestarting = false
            do {
                try self.beginListening()
            } catch {
                HostWakeLog.write(
                    "Mac listener restarted with an error: \(error.localizedDescription)"
                )
            }
        }
    }

    private func triggerSimulator() {
        var environment = ProcessInfo.processInfo.environment
        if let developerDir {
            environment["DEVELOPER_DIR"] = developerDir
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "simctl",
            "openurl",
            simulatorID,
            "gia://wake"
        ]
        process.environment = environment
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError
        do {
            try process.run()
        } catch {
            HostWakeLog.write(
                "Could not reach Simulator: \(error.localizedDescription)"
            )
        }
    }

}
