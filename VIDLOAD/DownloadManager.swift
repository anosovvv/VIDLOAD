//
//  DownloadManager.swift
//  VIDLOAD
//

import AppKit
import Combine
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    func text(_ russian: String, _ english: String) -> String {
        self == .russian ? russian : english
    }
}

enum DownloadStage: Equatable {
    case idle
    case preparing
    case downloading
    case converting

    func title(in language: AppLanguage) -> String {
        switch self {
        case .idle: ""
        case .preparing: language.text("Подготовка к загрузке", "Preparing download")
        case .downloading: language.text("Этап 1 из 2 — загрузка видео", "Step 1 of 2 — downloading video")
        case .converting: language.text("Этап 2 из 2 — подготовка для QuickTime", "Step 2 of 2 — preparing for QuickTime")
        }
    }

    var usesIndeterminateProgress: Bool {
        self == .preparing
    }
}

enum DownloadFormat: String, CaseIterable, Identifiable {
    case mp4Best
    case mp4_1080
    case mp4_720
    case mp3

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .mp4Best: language.text("MP4 — лучшее доступное качество", "MP4 — best available quality")
        case .mp4_1080: "MP4 — up to 1080p"
        case .mp4_720: "MP4 — up to 720p"
        case .mp3: language.text("MP3 — только аудио", "MP3 — audio only")
        }
    }

    func shortTitle(in language: AppLanguage) -> String {
        switch self {
        case .mp4Best: language.text("MP4 · лучшее", "MP4 · best")
        case .mp4_1080: "MP4 · 1080p"
        case .mp4_720: "MP4 · 720p"
        case .mp3: language.text("MP3 · аудио", "MP3 · audio")
        }
    }

    func helperText(in language: AppLanguage) -> String {
        switch self {
        case .mp3:
            language.text("Будет сохранён только звук в MP3.", "Only the audio will be saved as MP3.")
        default:
            language.text(
                "MP4 автоматически подготавливается для QuickTime: H.264-видео и AAC-аудио.",
                "MP4 is prepared for QuickTime automatically: H.264 video and AAC audio."
            )
        }
    }

    var ytDlpArguments: [String] {
        switch self {
        case .mp4Best:
            ["-f", "bv*[vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a]/b[vcodec^=avc1][ext=mp4]/bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]"]
        case .mp4_1080:
            ["-f", "bv*[height<=1080][vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a]/b[height<=1080][vcodec^=avc1][ext=mp4]/bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]"]
        case .mp4_720:
            ["-f", "bv*[height<=720][vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a]/b[height<=720][vcodec^=avc1][ext=mp4]/bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]"]
        case .mp3:
            ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        }
    }

    var needsMP4Merge: Bool { self != .mp3 }
}

struct ToolLocation: Equatable {
    let name: String
    let url: URL?
    let isBundled: Bool

    init(name: String, url: URL?, isBundled: Bool = false) {
        self.name = name
        self.url = url
        self.isBundled = isBundled
    }

    var isAvailable: Bool { url != nil }

    func detail(in language: AppLanguage) -> String {
        guard let url else { return language.text("Не найден", "Not found") }
        return isBundled
            ? language.text("Встроено в VIDLOAD", "Built into VIDLOAD")
            : language.text("Готово: \(url.path)", "Ready: \(url.path)")
    }
}

struct DependencyStatus: Equatable {
    let ytDlp: ToolLocation
    let ffmpeg: ToolLocation

    var isReady: Bool { ytDlp.isAvailable && ffmpeg.isAvailable }

    static func detect() -> DependencyStatus {
        DependencyStatus(
            ytDlp: bundledTool(named: "yt-dlp", pathComponents: ["bin", "yt-dlp"]) ??
                ToolLocation(name: "yt-dlp", url: findExecutable(named: "yt-dlp")),
            ffmpeg: bundledTool(
                named: "ffmpeg",
                pathComponents: [bundledArchitecture, "bin", "ffmpeg"]
            ) ??
                ToolLocation(name: "ffmpeg", url: findExecutable(named: "ffmpeg"))
        )
    }

    private static var bundledArchitecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    static var javaScriptRuntime: URL? {
        bundledTool(named: "deno", pathComponents: [bundledArchitecture, "bin", "deno"])?.url
            ?? findExecutable(named: "deno")
    }

    private static func bundledTool(named name: String, pathComponents: [String]) -> ToolLocation? {
        // The tools live in a nested .bundle so Xcode preserves the FFmpeg
        // executables' adjacent dynamic libraries instead of flattening them.
        guard let toolsBundleURL = Bundle.main.url(forResource: "VIDLOADTools", withExtension: "bundle") else {
            return nil
        }

        let toolURL = pathComponents.reduce(toolsBundleURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
        guard FileManager.default.isExecutableFile(atPath: toolURL.path) else { return nil }
        return ToolLocation(name: name, url: toolURL, isBundled: true)
    }

    private static func findExecutable(named name: String) -> URL? {
        let environmentPaths = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/opt/local/bin"
        ]

        for directory in environmentPaths + commonPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var dependencies = DependencyStatus.detect()
    @Published private(set) var progress = 0.0
    @Published private(set) var statusMessage = "Проверяем необходимые инструменты…"
    @Published private(set) var progressDetail = ""
    @Published private(set) var stage: DownloadStage = .idle
    @Published private(set) var logLines: [String] = []
    @Published private(set) var lastOutputFile: URL?
    @Published private(set) var isDownloading = false
    @Published var destinationURL: URL

    private let destinationDefaultsKey = "VIDLOAD.destinationURL"
    private var language: AppLanguage = .russian
    private var process: Process?
    private var pendingOutput = ""
    private var cancellationRequested = false
    private var usesSafariCookiesForCurrentDownload = false
    private var currentDownloadNeedsQuickTimeConversion = false
    private var conversionPendingOutput = ""
    private var conversionDuration: TimeInterval?
    private var conversionProcessedSeconds: TimeInterval = 0
    private var conversionSpeed = ""

    init() {
        if let path = UserDefaults.standard.string(forKey: destinationDefaultsKey) {
            destinationURL = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            destinationURL = downloads.appendingPathComponent("VIDLOAD", isDirectory: true)
        }
        updateReadyMessage()
    }

    var statusSymbol: String {
        if statusMessage.hasPrefix(language.text("Готово", "Done")) { return "checkmark.circle.fill" }
        if statusMessage.hasPrefix(language.text("Ошибка", "Error")) { return "xmark.octagon.fill" }
        if statusMessage.hasPrefix(language.text("Отменено", "Cancelled")) { return "minus.circle.fill" }
        return "info.circle.fill"
    }

    var statusColor: Color {
        if statusMessage.hasPrefix(language.text("Готово", "Done")) { return .green }
        if statusMessage.hasPrefix(language.text("Ошибка", "Error")) { return .red }
        if statusMessage.hasPrefix(language.text("Отменено", "Cancelled")) { return .orange }
        return .secondary
    }

    func refreshDependencies() {
        dependencies = DependencyStatus.detect()
        updateReadyMessage()
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        if !isDownloading {
            updateReadyMessage()
        }
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = language.text("Выберите папку для загрузок", "Choose a download folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = language.text("Выбрать", "Choose")
        panel.directoryURL = destinationURL

        if panel.runModal() == .OK, let selectedURL = panel.url {
            destinationURL = selectedURL
            UserDefaults.standard.set(selectedURL.path, forKey: destinationDefaultsKey)
        }
    }

    func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
        statusMessage = language.text("Команда установки скопирована.", "Installation command copied.")
    }

    func reveal(_ file: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    func startDownload(
        link rawLink: String,
        format: DownloadFormat,
        useSafariSession: Bool
    ) {
        guard !isDownloading else { return }
        refreshDependencies()

        guard dependencies.isReady,
              let ytDlpURL = dependencies.ytDlp.url,
              let ffmpegURL = dependencies.ffmpeg.url else {
            statusMessage = language.text(
                "Ошибка: установите yt-dlp и FFmpeg, затем проверьте инструменты ещё раз.",
                "Error: install yt-dlp and FFmpeg, then check the tools again."
            )
            return
        }
        guard let videoURL = validatedVideoURL(from: rawLink) else {
            statusMessage = language.text(
                "Ошибка: вставьте действующую публичную ссылку YouTube или Instagram.",
                "Error: paste a valid public YouTube or Instagram link."
            )
            return
        }

        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            try launchDownload(
                for: videoURL,
                format: format,
                ytDlpURL: ytDlpURL,
                ffmpegURL: ffmpegURL,
                useSafariCookies: useSafariSession
            )
        } catch {
            isDownloading = false
            process = nil
            statusMessage = language.text(
                "Ошибка: не удалось запустить загрузку — \(error.localizedDescription)",
                "Error: could not start the download — \(error.localizedDescription)"
            )
        }
    }

    func cancelDownload() {
        guard isDownloading else { return }
        cancellationRequested = true
        statusMessage = language.text("Отмена загрузки…", "Cancelling download…")
        process?.terminate()
    }

    private func launchDownload(
        for videoURL: URL,
        format: DownloadFormat,
        ytDlpURL: URL,
        ffmpegURL: URL,
        useSafariCookies: Bool
    ) throws {
        let downloadProcess = Process()
        let outputPipe = Pipe()
        let outputTemplate = destinationURL
            .appendingPathComponent("%(title).200B [%(id)s].%(ext)s")
            .path

        var arguments = [
            "--ignore-config",
            "--newline",
            "--no-playlist",
            "--progress-delta", "0.25",
            "--ffmpeg-location", ffmpegURL.deletingLastPathComponent().path,
            "--progress-template", "download:PROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:FILE:%(filepath)s",
            "-o", outputTemplate
        ]
        if let runtime = DependencyStatus.javaScriptRuntime {
            arguments += ["--js-runtimes", "deno:\(runtime.path)"]
        }
        if useSafariCookies {
            arguments += ["--cookies-from-browser", "safari"]
        }
        arguments += format.ytDlpArguments
        if format.needsMP4Merge {
            arguments += ["--merge-output-format", "mp4"]
        }
        arguments += [videoURL.absoluteString]

        downloadProcess.executableURL = ytDlpURL
        downloadProcess.arguments = arguments
        downloadProcess.standardOutput = outputPipe
        downloadProcess.standardError = outputPipe
        downloadProcess.environment = processEnvironment(including: ytDlpURL, ffmpegURL)

        pendingOutput = ""
        logLines = []
        progress = 0
        stage = .preparing
        progressDetail = useSafariCookies
            ? language.text(
                "Подключаем текущую сессию Safari и проверяем доступные форматы.",
                "Connecting the current Safari session and checking available formats."
            )
            : language.text("Проверяем доступные форматы видео.", "Checking available video formats.")
        statusMessage = useSafariCookies
            ? language.text("Подключаем сессию Safari…", "Connecting Safari session…")
            : language.text("Загрузка началась…", "Download started…")
        lastOutputFile = nil
        cancellationRequested = false
        usesSafariCookiesForCurrentDownload = useSafariCookies
        currentDownloadNeedsQuickTimeConversion = format.needsMP4Merge
        isDownloading = true
        process = downloadProcess

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.consume(data: data)
            }
        }
        downloadProcess.terminationHandler = { [weak self, weak outputPipe] runningProcess in
            outputPipe?.fileHandleForReading.readabilityHandler = nil
            let exitCode = runningProcess.terminationStatus
            Task { @MainActor [weak self] in
                self?.finishDownload(exitCode: exitCode)
            }
        }

        try downloadProcess.run()
    }

    private func processEnvironment(including ytDlpURL: URL, _ ffmpegURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let directories = [
            ytDlpURL.deletingLastPathComponent().path,
            ffmpegURL.deletingLastPathComponent().path,
            environment["PATH"] ?? ""
        ]
        environment["PATH"] = directories.filter { !$0.isEmpty }.joined(separator: ":")
        return environment
    }

    private func consume(data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        pendingOutput += string
        let lines = pendingOutput.components(separatedBy: .newlines)
        pendingOutput = lines.last ?? ""
        for line in lines.dropLast() {
            handleOutputLine(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func handleOutputLine(_ line: String) {
        guard !line.isEmpty else { return }
        logLines.insert(line, at: 0)
        if logLines.count > 8 { logLines.removeLast() }

        if let progressRange = line.range(of: "PROGRESS:") {
            stage = .downloading
            statusMessage = language.text("Загружаем видео…", "Downloading video…")
            let fields = line[progressRange.upperBound...].split(separator: "|", omittingEmptySubsequences: false)
            if let rawPercentage = fields.first {
                let percentage = rawPercentage
                    .replacingOccurrences(of: "%", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let number = Double(percentage) {
                    progress = min(max(number / 100, 0), 1)
                }
            }
            let speed = fields.count > 1 ? fields[1].trimmingCharacters(in: .whitespaces) : ""
            let eta = fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespaces) : ""
            progressDetail = [
                speed.isEmpty ? nil : speed,
                eta.isEmpty ? nil : language.text("осталось \(eta)", "\(eta) remaining")
            ]
                .compactMap { $0 }
                .joined(separator: " · ")
        } else if stage == .preparing && (line.contains("[download] Destination:") || line.contains("[download] Downloading")) {
            stage = .downloading
            statusMessage = language.text("Загружаем видео…", "Downloading video…")
            progressDetail = language.text("Получаем данные…", "Receiving data…")
        }

        if let fileRange = line.range(of: "FILE:") {
            let path = String(line[fileRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { lastOutputFile = URL(fileURLWithPath: path) }
        }
    }

    private func finishDownload(exitCode: Int32) {
        if !pendingOutput.isEmpty {
            handleOutputLine(pendingOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            pendingOutput = ""
        }
        isDownloading = false
        process = nil
        progressDetail = ""

        if cancellationRequested {
            stage = .idle
            statusMessage = language.text("Отменено пользователем.", "Cancelled by user.")
        } else if exitCode == 0 {
            if currentDownloadNeedsQuickTimeConversion,
               let outputFile = lastOutputFile,
               FileManager.default.fileExists(atPath: outputFile.path),
               let ffmpegURL = dependencies.ffmpeg.url {
                do {
                    try launchQuickTimeConversion(of: outputFile, with: ffmpegURL)
                    return
                } catch {
                    statusMessage = language.text(
                        "Файл сохранён, но не удалось подготовить его для QuickTime: \(error.localizedDescription)",
                        "The file was saved, but could not be prepared for QuickTime: \(error.localizedDescription)"
                    )
                    return
                }
            }
            progress = 1
            stage = .idle
            statusMessage = language.text(
                "Готово: файл сохранён в выбранную папку.",
                "Done: the file was saved to the selected folder."
            )
        } else if isSafariCookieAccessDenied() {
            stage = .idle
            statusMessage = language.text(
                "Ошибка: macOS не разрешила VIDLOAD доступ к cookie Safari. Включите «Полный доступ к диску» для VIDLOAD и перезапустите приложение.",
                "Error: macOS did not allow VIDLOAD to access Safari cookies. Enable Full Disk Access for VIDLOAD and restart the app."
            )
        } else if !usesSafariCookiesForCurrentDownload && logLines.joined(separator: " ").localizedCaseInsensitiveContains("rate-limit") {
            stage = .idle
            statusMessage = language.text(
                "Ошибка: Instagram ограничил анонимный доступ. Включите сессию Safari и повторите попытку.",
                "Error: Instagram limited anonymous access. Enable the Safari session and try again."
            )
        } else if isYouTubeBotCheck() {
            stage = .idle
            statusMessage = usesSafariCookiesForCurrentDownload
                ? language.text(
                    "Ошибка: YouTube временно ограничил эту сессию. Проверьте вход в YouTube через Safari и повторите попытку позже.",
                    "Error: YouTube temporarily limited this session. Check your YouTube sign-in in Safari and try again later."
                )
                : language.text(
                    "Ошибка: YouTube запросил вход. Войдите в YouTube через Safari, включите сессию Safari и повторите попытку.",
                    "Error: YouTube requested a sign-in. Sign in to YouTube in Safari, enable the Safari session, and try again."
                )
        } else {
            stage = .idle
            statusMessage = language.text(
                "Ошибка: yt-dlp завершился с кодом \(exitCode). Проверьте последние сообщения.",
                "Error: yt-dlp exited with code \(exitCode). Check the latest messages."
            )
        }
    }

    private func launchQuickTimeConversion(of sourceURL: URL, with ffmpegURL: URL) throws {
        let temporaryURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent(".vidload-quicktime-\(UUID().uuidString).mp4")
        let conversionProcess = Process()
        let progressPipe = Pipe()

        conversionProcess.executableURL = ffmpegURL
        conversionProcess.arguments = [
            "-hide_banner",
            "-nostats",
            "-y",
            "-i", sourceURL.path,
            "-map", "0:v:0?",
            "-map", "0:a?",
            "-map_metadata", "0",
            // This uses macOS VideoToolbox rather than a separately licensed
            // software H.264 encoder, so the bundled tools stay self-contained.
            "-c:v", "h264_videotoolbox",
            "-b:v", "12M",
            "-maxrate", "16M",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            temporaryURL.path
        ]
        conversionProcess.environment = processEnvironment(including: ffmpegURL, ffmpegURL)
        conversionProcess.standardOutput = progressPipe
        conversionProcess.standardError = FileHandle.nullDevice
        progressPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.consumeConversionProgress(data: data)
            }
        }
        conversionProcess.terminationHandler = { [weak self, weak progressPipe] runningProcess in
            progressPipe?.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor [weak self] in
                self?.finishQuickTimeConversion(
                    exitCode: runningProcess.terminationStatus,
                    sourceURL: sourceURL,
                    temporaryURL: temporaryURL
                )
            }
        }

        conversionPendingOutput = ""
        conversionDuration = mediaDuration(of: sourceURL, using: ffmpegURL)
        conversionProcessedSeconds = 0
        conversionSpeed = ""
        progress = 0
        stage = .converting
        progressDetail = conversionDuration.map {
            language.text("0:00 из \(formattedDuration($0))", "0:00 of \(formattedDuration($0))")
        } ?? language.text("Определяем ход обработки…", "Calculating conversion progress…")
        statusMessage = language.text("Конвертируем для QuickTime…", "Converting for QuickTime…")
        isDownloading = true
        process = conversionProcess
        do {
            try conversionProcess.run()
        } catch {
            isDownloading = false
            process = nil
            throw error
        }
    }

    private func finishQuickTimeConversion(exitCode: Int32, sourceURL: URL, temporaryURL: URL) {
        isDownloading = false
        process = nil
        progressDetail = ""

        guard !cancellationRequested else {
            try? FileManager.default.removeItem(at: temporaryURL)
            stage = .idle
            statusMessage = language.text(
                "Отменено пользователем. Исходный файл сохранён.",
                "Cancelled by user. The original file was kept."
            )
            return
        }

        guard exitCode == 0, FileManager.default.fileExists(atPath: temporaryURL.path) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            stage = .idle
            statusMessage = language.text(
                "Файл сохранён, но не удалось подготовить совместимую версию для QuickTime.",
                "The file was saved, but a QuickTime-compatible version could not be prepared."
            )
            return
        }

        do {
            _ = try FileManager.default.replaceItemAt(sourceURL, withItemAt: temporaryURL)
            lastOutputFile = sourceURL
            progress = 1
            stage = .idle
            statusMessage = language.text("Готово: MP4 подготовлен для QuickTime.", "Done: MP4 prepared for QuickTime.")
        } catch {
            lastOutputFile = temporaryURL
            progress = 1
            stage = .idle
            statusMessage = language.text(
                "Готово: совместимая копия сохранена рядом с исходным файлом.",
                "Done: a compatible copy was saved next to the original file."
            )
        }
    }

    private func consumeConversionProgress(data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        conversionPendingOutput += string
        let lines = conversionPendingOutput.components(separatedBy: .newlines)
        conversionPendingOutput = lines.last ?? ""

        for line in lines.dropLast() {
            updateConversionProgress(from: line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func updateConversionProgress(from line: String) {
        if line.hasPrefix("out_time_us="),
           let value = Double(line.dropFirst("out_time_us=".count)) {
            conversionProcessedSeconds = value / 1_000_000
        } else if line.hasPrefix("out_time_ms="),
                  let value = Double(line.dropFirst("out_time_ms=".count)) {
            conversionProcessedSeconds = value / 1_000_000
        } else if line.hasPrefix("out_time=") {
            conversionProcessedSeconds = parsedFFmpegTime(String(line.dropFirst("out_time=".count))) ?? conversionProcessedSeconds
        } else if line.hasPrefix("speed=") {
            conversionSpeed = String(line.dropFirst("speed=".count)).trimmingCharacters(in: .whitespaces)
            return
        } else {
            return
        }

        guard conversionProcessedSeconds > 0 else { return }
        if let conversionDuration, conversionDuration > 0 {
            progress = min(conversionProcessedSeconds / conversionDuration, 0.995)
            progressDetail = language.text(
                "\(formattedDuration(conversionProcessedSeconds)) из \(formattedDuration(conversionDuration))",
                "\(formattedDuration(conversionProcessedSeconds)) of \(formattedDuration(conversionDuration))"
            ) + (conversionSpeed.isEmpty ? "" : " · \(conversionSpeed)")
        } else {
            progressDetail = language.text(
                "Обработано \(formattedDuration(conversionProcessedSeconds))",
                "Processed \(formattedDuration(conversionProcessedSeconds))"
            ) + (conversionSpeed.isEmpty ? "" : " · \(conversionSpeed)")
        }
    }

    private func mediaDuration(of sourceURL: URL, using ffmpegURL: URL) -> TimeInterval? {
        let ffprobeName = ffmpegURL.lastPathComponent.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        let ffprobeURL = ffmpegURL.deletingLastPathComponent().appendingPathComponent(ffprobeName)
        guard FileManager.default.isExecutableFile(atPath: ffprobeURL.path) else { return nil }

        let probe = Process()
        let outputPipe = Pipe()
        probe.executableURL = ffprobeURL
        probe.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            sourceURL.path
        ]
        probe.standardOutput = outputPipe
        probe.standardError = FileHandle.nullDevice
        probe.environment = processEnvironment(including: ffmpegURL, ffmpegURL)

        do {
            try probe.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            probe.waitUntilExit()
            guard probe.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8),
                  let duration = TimeInterval(output.trimmingCharacters(in: .whitespacesAndNewlines)),
                  duration > 0 else {
                return nil
            }
            return duration
        } catch {
            return nil
        }
    }

    private func parsedFFmpegTime(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: ":").compactMap { TimeInterval($0) }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3_600 + parts[1] * 60 + parts[2]
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func updateReadyMessage() {
        statusMessage = dependencies.isReady
            ? language.text(
                "Инструменты готовы. Вставьте ссылку на публичное видео.",
                "Tools are ready. Paste a public video link."
            )
            : language.text("Нужны yt-dlp и FFmpeg для загрузки.", "yt-dlp and FFmpeg are needed for downloads.")
    }

    private func validatedVideoURL(from rawLink: String) -> URL? {
        let trimmedLink = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedLink),
              let host = url.host?.lowercased(),
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }

        let isYouTube = host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be"
        let isInstagram = isInstagramHost(host)
        return (isYouTube || isInstagram) ? url : nil
    }

    private func isYouTubeBotCheck() -> Bool {
        let output = logLines.joined(separator: " ").lowercased()
        return output.contains("sign in to confirm") || output.contains("http error 429")
    }

    private func isSafariCookieAccessDenied() -> Bool {
        let output = logLines.joined(separator: " ").lowercased()
        return output.contains("operation not permitted") && output.contains("cookies.binarycookies")
    }

    private func isInstagramHost(_ host: String) -> Bool {
        host == "instagram.com" || host.hasSuffix(".instagram.com")
    }
}
