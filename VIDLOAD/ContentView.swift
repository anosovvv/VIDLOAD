//
//  ContentView.swift
//  VIDLOAD
//

import SwiftUI

struct ContentView: View {
    @StateObject private var downloadManager = DownloadManager()
    @State private var link = ""
    @State private var selectedFormat: DownloadFormat = .mp4Best
    @State private var useSafariSession = false
    @State private var isPrivacyInfoPresented = false
    @AppStorage("VIDLOAD.hasSeenPrivacyInfo") private var hasSeenPrivacyInfo = false
    @AppStorage("VIDLOAD.language") private var languageRawValue = AppLanguage.russian.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .russian
    }

    private func text(_ russian: String, _ english: String) -> String {
        language.text(russian, english)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section {
                    HStack(spacing: 10) {
                        TextField(text("Вставьте ссылку", "Paste a link"), text: $link)
                            .textFieldStyle(.roundedBorder)

                        Picker(text("Формат", "Format"), selection: $selectedFormat) {
                            ForEach(DownloadFormat.allCases) { format in
                                Text(format.shortTitle(in: language)).tag(format)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)

                        downloadButton
                    }

                    Text(text(
                        "Вставьте ссылку и нажмите «Скачать». Поддерживаются публичные видео YouTube и Instagram.",
                        "Paste a link and click Download. Public YouTube and Instagram videos are supported."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selectedFormat.helperText(in: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    progressSection

                    HStack {
                        Button(text("Проверить инструменты", "Check tools")) { downloadManager.refreshDependencies() }
                            .disabled(downloadManager.isDownloading)

                        if let outputFile = downloadManager.lastOutputFile {
                            Button(text("Показать в Finder", "Show in Finder")) { downloadManager.reveal(outputFile) }
                        }
                    }
                } header: {
                    Text(text("Новая загрузка", "New download"))
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(text("Папка загрузки", "Download folder"))
                            Text(downloadManager.destinationURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(text("Изменить…", "Change…")) { downloadManager.chooseDestination() }
                    }
                } header: {
                    Text(text("Сохранение", "Saving"))
                }

                Section {
                    Toggle(text("Использовать текущую сессию Safari", "Use current Safari session"), isOn: $useSafariSession)
                    Text(text(
                        "Опция используется только для YouTube и Instagram. Cookie из Safari не сохраняются и передаются только соответствующему сервису через yt-dlp для этой загрузки.",
                        "This option is used only for YouTube and Instagram. Safari cookies are not saved and are sent only to the matching service through yt-dlp for this download."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(text("Сессия Safari", "Safari session"))
                }

                Section {
                    DependencyRow(name: "yt-dlp", tool: downloadManager.dependencies.ytDlp, language: language)
                    DependencyRow(name: "FFmpeg", tool: downloadManager.dependencies.ffmpeg, language: language)

                    if !downloadManager.dependencies.isReady {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(text(
                                "Встроенные инструменты не найдены. Для разработки можно установить их в Терминале:",
                                "Built-in tools were not found. For development, install them in Terminal:"
                            ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("brew install yt-dlp ffmpeg")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Button(text("Скопировать", "Copy")) { downloadManager.copyInstallCommand() }
                            }
                        }
                    }
                } header: {
                    Text(text("Инструменты", "Tools"))
                }

                if !downloadManager.logLines.isEmpty {
                    Section {
                        Text(downloadManager.logLines.joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(text("Последние сообщения", "Latest messages"))
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 720, minHeight: 610)
        .onAppear {
            downloadManager.setLanguage(language)
            downloadManager.refreshDependencies()
            if !hasSeenPrivacyInfo {
                isPrivacyInfoPresented = true
            }
        }
        .sheet(isPresented: $isPrivacyInfoPresented, onDismiss: {
            hasSeenPrivacyInfo = true
        }) {
            PrivacyInfoSheet(language: language, isPresented: $isPrivacyInfoPresented)
        }
        .onChange(of: languageRawValue) { _, _ in
            downloadManager.setLanguage(language)
        }
    }

    private var downloadButton: some View {
        Button {
            if downloadManager.isDownloading {
                downloadManager.cancelDownload()
            } else {
                downloadManager.startDownload(
                    link: link,
                    format: selectedFormat,
                    useSafariSession: useSafariSession
                )
            }
        } label: {
            Label(
                downloadManager.isDownloading
                    ? text("Отменить", "Cancel")
                    : text("Скачать", "Download"),
                systemImage: downloadManager.isDownloading ? "stop.fill" : "arrow.down.circle.fill"
            )
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!downloadManager.isDownloading && !downloadManager.dependencies.isReady)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("VIDLOAD").font(.title2.bold())
                Text(text("Сохраняйте разрешённые публичные видео на Mac", "Save permitted public videos on your Mac"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Language", selection: $languageRawValue) {
                Text("RU").tag(AppLanguage.russian.rawValue)
                Text("EN").tag(AppLanguage.english.rawValue)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 82)
            Button {
                isPrivacyInfoPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .help(text("Как VIDLOAD использует сессию Safari", "How VIDLOAD uses the Safari session"))
        }
        .padding(20)
        .background(.bar)
    }

    @ViewBuilder
    private var progressSection: some View {
        if downloadManager.isDownloading {
            VStack(alignment: .leading, spacing: 6) {
                Text(downloadManager.stage.title(in: language))
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
    let language: AppLanguage
    @Binding var isPresented: Bool

    private func text(_ russian: String, _ english: String) -> String {
        language.text(russian, english)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(text("Прозрачность и разрешения", "Transparency and permissions"), systemImage: "hand.raised.fill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Label(text("Что скачивает VIDLOAD", "What VIDLOAD downloads"), systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                Text(text(
                    "Только материалы по вставленной вами публичной ссылке. Скачивайте собственные материалы или материалы, на которые у вас есть разрешение.",
                    "Only material from the public link you paste. Download your own material or material you are allowed to download."
                ))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(text("Зачем нужен полный доступ к диску", "Why Full Disk Access is needed"), systemImage: "externaldrive.fill")
                    .font(.headline)
                Text(text(
                    "Он нужен только если включить сессию Safari: macOS защищает файл cookie браузера. Разрешение широкое, поэтому включайте его лишь для этой локальной сборки, которой доверяете.",
                    "It is needed only when you enable the Safari session: macOS protects the browser cookie file. This is broad access, so enable it only for this local app build that you trust."
                ))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(text("Что такое сессия Safari", "What the Safari session is"), systemImage: "safari.fill")
                    .font(.headline)
                Text(text(
                    "Это текущий вход в YouTube или Instagram в Safari. При включённой опции cookie не сохраняются и передаются только выбранному сервису для одной загрузки. Они могут помочь, когда сервис просит войти в аккаунт.",
                    "It is your current YouTube or Instagram sign-in in Safari. When enabled, cookies are not saved and are sent only to the selected service for one download. They can help when a service requires you to sign in."
                ))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(text("Понятно", "Got it")) {
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
    let language: AppLanguage

    var body: some View {
        HStack {
            Image(systemName: tool.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tool.isAvailable ? .green : .orange)
            Text(name)
            Spacer()
            Text(tool.detail(in: language))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    ContentView()
}
