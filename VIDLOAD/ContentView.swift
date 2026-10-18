//
//  ContentView.swift
//  VIDLOAD
//

import SwiftUI

struct ContentView: View {
    @StateObject private var downloadManager = DownloadManager()
    @State private var link = ""
    @State private var selectedFormat: DownloadFormat = .mp4Best
    @State private var confirmedPermission = false
    @State private var useSafariSession = false
    @State private var isPrivacyInfoPresented = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section("Ссылка") {
                    TextField("Ссылка на публичное видео YouTube или Instagram", text: $link)
                        .textFieldStyle(.roundedBorder)
                    Text("Поддерживаются только публичные видео. Приватные материалы и DRM не поддерживаются.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Сохранение") {
                    Picker("Формат", selection: $selectedFormat) {
                        ForEach(DownloadFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    Text("MP4 автоматически подготавливается для QuickTime: H.264-видео и AAC-аудио.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Папка загрузки")
                            Text(downloadManager.destinationURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Изменить…") { downloadManager.chooseDestination() }
                    }
                }

                Section("Разрешение") {
                    Toggle("У меня есть право скачать этот материал", isOn: $confirmedPermission)
                    Text("Скачивайте только собственные материалы или материалы, для которых у вас есть разрешение, и соблюдайте правила сервиса.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Сессия Safari") {
                    Toggle("Использовать текущую сессию Safari", isOn: $useSafariSession)
                    Text("Опция используется только для YouTube и Instagram. Cookie из Safari не сохраняются и передаются только соответствующему сервису через yt-dlp для этой загрузки.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Загрузка") {
                    progressSection

                    HStack {
                        Button {
                            if downloadManager.isDownloading {
                                downloadManager.cancelDownload()
                            } else {
                                downloadManager.startDownload(
                                    link: link,
                                    format: selectedFormat,
                                    permissionConfirmed: confirmedPermission,
                                    useSafariSession: useSafariSession
                                )
                            }
                        } label: {
                            Label(
                                downloadManager.isDownloading ? "Отменить" : "Скачать",
                                systemImage: downloadManager.isDownloading ? "stop.fill" : "arrow.down.circle.fill"
                            )
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!downloadManager.isDownloading && !downloadManager.dependencies.isReady)

                        Button("Проверить инструменты") { downloadManager.refreshDependencies() }
                            .disabled(downloadManager.isDownloading)

                        if let outputFile = downloadManager.lastOutputFile {
                            Button("Показать в Finder") { downloadManager.reveal(outputFile) }
                        }
                    }
                }

                Section("Инструменты") {
                    DependencyRow(name: "yt-dlp", tool: downloadManager.dependencies.ytDlp)
                    DependencyRow(name: "FFmpeg", tool: downloadManager.dependencies.ffmpeg)

                    if !downloadManager.dependencies.isReady {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Встроенные инструменты не найдены. Для разработки можно установить их в Терминале:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("brew install yt-dlp ffmpeg")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Button("Скопировать") { downloadManager.copyInstallCommand() }
                            }
                        }
                    }
                }

                if !downloadManager.logLines.isEmpty {
                    Section("Последние сообщения") {
                        Text(downloadManager.logLines.joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 720, minHeight: 610)
        .onAppear {
            downloadManager.refreshDependencies()
            isPrivacyInfoPresented = true
        }
        .sheet(isPresented: $isPrivacyInfoPresented) {
            PrivacyInfoSheet(isPresented: $isPrivacyInfoPresented)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("VIDLOAD").font(.title2.bold())
                Text("Сохраняйте разрешённые публичные видео на Mac")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isPrivacyInfoPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .help("Как VIDLOAD использует сессию Safari")
        }
        .padding(20)
        .background(.bar)
    }

    @ViewBuilder
    private var progressSection: some View {
        if downloadManager.isDownloading {
            VStack(alignment: .leading, spacing: 6) {
                Text(downloadManager.stage.title)
                    .font(.headline)
                if downloadManager.stage.usesIndeterminateProgress {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(downloadManager.statusMessage)
                    }
                } else {
                    ProgressView(value: downloadManager.progress) {
                        Text(downloadManager.statusMessage)
                    } currentValueLabel: {
                        Text("\(Int(downloadManager.progress * 100))%").monospacedDigit()
                    }
                }
                if !downloadManager.progressDetail.isEmpty {
                    Text(downloadManager.progressDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Label(downloadManager.statusMessage, systemImage: downloadManager.statusSymbol)
                .foregroundStyle(downloadManager.statusColor)
        }
    }
}

private struct PrivacyInfoSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Прозрачность и разрешения", systemImage: "hand.raised.fill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Label("Что скачивает VIDLOAD", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                Text("Только материалы по вставленной вами публичной ссылке — и только после подтверждения, что у вас есть право на загрузку.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Зачем нужен полный доступ к диску", systemImage: "externaldrive.fill")
                    .font(.headline)
                Text("Он нужен только если включить сессию Safari: macOS защищает файл cookie браузера. Разрешение широкое, поэтому включайте его лишь для этой локальной сборки, которой доверяете.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Что такое сессия Safari", systemImage: "safari.fill")
                    .font(.headline)
                Text("Это текущий вход в YouTube или Instagram в Safari. При включённой опции cookie не сохраняются и передаются только выбранному сервису для одной загрузки. Они могут помочь, когда сервис просит войти в аккаунт.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Понятно") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

private struct DependencyRow: View {
    let name: String
    let tool: ToolLocation

    var body: some View {
        HStack {
            Image(systemName: tool.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tool.isAvailable ? .green : .orange)
            Text(name)
            Spacer()
            Text(tool.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    ContentView()
}
