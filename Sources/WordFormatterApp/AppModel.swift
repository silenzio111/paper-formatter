import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var config = FormatterConfig()
    @Published var selectedEngine: FormatterEngine = .pythonDocx
    @Published var selectedSection: FormatterSection = .body
    @Published var selectedDestination: WorkspaceDestination = .overview
    @Published var inputURL: URL?
    @Published var outputURL: URL?
    @Published var shouldOverwriteInput = false
    @Published var summary = DocumentSummary()
    @Published var warnings: [String] = []
    @Published var statusMessage = "选择一个 DOCX 文档开始分析"
    @Published private(set) var hasFormattedCurrentTarget = false
    @Published var isInspecting = false
    @Published var isFormatting = false
    @Published var isDropTargeted = false
    @Published var alertMessage: String?
    @Published var overwriteURL: URL?
    @Published var configFileURL: URL?

    private var savedConfig = FormatterConfig()
    private var pendingFormatScope = "all"
    private var alternativeOutputURL: URL?
    private let engine = PythonEngineClient()

    var hasUnsavedConfigChanges: Bool {
        config != savedConfig
    }

    var outputExists: Bool {
        guard let outputURL else { return false }
        return FileManager.default.fileExists(atPath: outputURL.path)
    }

    var isOverwritingInput: Bool {
        guard shouldOverwriteInput, let inputURL, let outputURL else { return false }
        return isSameDocument(inputURL, outputURL)
    }

    var canOpenOutput: Bool {
        outputExists && (!isOverwritingInput || hasFormattedCurrentTarget)
    }

    var overwriteConfirmationTitle: String {
        isOverwritingInput ? "确认覆盖原始文档" : "输出文件已存在"
    }

    var overwriteConfirmationButtonTitle: String {
        isOverwritingInput ? "覆盖原文并排版" : "覆盖并排版"
    }

    var overwriteConfirmationMessage: String {
        guard let overwriteURL else { return "" }
        if isOverwritingInput {
            return "原始 DOCX 会先移入废纸篓，再以同名排版结果替代：\n\(overwriteURL.path)"
        }
        return overwriteURL.path
    }

    var canFormat: Bool {
        guard let inputURL, let outputURL else { return false }
        return (isOverwritingInput || !isSameDocument(inputURL, outputURL)) && !isInspecting && !isFormatting
    }

    func select(_ destination: WorkspaceDestination) {
        selectedDestination = destination
        if let ruleSection = destination.ruleSection {
            selectedSection = ruleSection
        }
    }

    func chooseInputDocument() {
        let panel = NSOpenPanel()
        panel.title = "选择需要排版的 Word 文档"
        panel.message = "请选择 .docx 文件"
        panel.allowedContentTypes = [.init(filenameExtension: "docx") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadInputDocument(url)
    }

    func loadInputDocument(_ url: URL) {
        guard !isFormatting else {
            alertMessage = "正在排版，请等待当前任务完成后再切换文档。"
            return
        }
        guard url.pathExtension.lowercased() == "docx" else {
            alertMessage = "只能载入 .docx 文件。"
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            alertMessage = "找不到所选文档：\(url.path)"
            return
        }

        inputURL = url.standardizedFileURL
        shouldOverwriteInput = false
        alternativeOutputURL = nil
        outputURL = defaultOutputURL(for: url)
        hasFormattedCurrentTarget = false
        summary = DocumentSummary()
        warnings = []
        statusMessage = "正在读取文档结构…"
        selectedDestination = .overview
        inspectDocument()
    }

    func chooseOutputDocument() {
        let panel = NSSavePanel()
        panel.title = "选择排版后的保存位置"
        panel.message = "输出文件会保留原文档，另存为新的 DOCX"
        panel.allowedContentTypes = [.init(filenameExtension: "docx") ?? .data]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? "formatted.docx"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let candidate = url.pathExtension.lowercased() == "docx"
            ? url
            : url.appendingPathExtension("docx")
        if let inputURL, isSameDocument(inputURL, candidate) {
            alertMessage = "输出文件不能覆盖输入文档，请选择其他位置。"
            return
        }
        outputURL = candidate.standardizedFileURL
        alternativeOutputURL = outputURL
        shouldOverwriteInput = false
        hasFormattedCurrentTarget = false
        statusMessage = "输出位置已更新。"
    }

    func setOverwriteInput(_ enabled: Bool) {
        guard let inputURL else {
            shouldOverwriteInput = false
            return
        }

        if enabled {
            if let currentOutput = outputURL, !isSameDocument(inputURL, currentOutput) {
                alternativeOutputURL = currentOutput
            }
            shouldOverwriteInput = true
            outputURL = inputURL
            hasFormattedCurrentTarget = false
            statusMessage = "已设为覆盖原始文档；原文件会移入废纸篓，开始排版时会再次确认。"
        } else {
            shouldOverwriteInput = false
            outputURL = alternativeOutputURL ?? defaultOutputURL(for: inputURL)
            hasFormattedCurrentTarget = false
            statusMessage = "已恢复为生成新的排版文件。"
        }
    }

    func engineChanged(_ engine: FormatterEngine) {
        selectedEngine = engine
        guard inputURL != nil, !isInspecting, !isFormatting else { return }
        inspectDocument()
    }

    func inspectDocument() {
        guard let inputURL else {
            statusMessage = "请先选择输入文档"
            return
        }
        isInspecting = true
        statusMessage = "正在读取文档结构…"
        let request = EngineRequest(
            action: "inspect",
            engine: selectedEngine.rawValue,
            inputPath: inputURL.path,
            outputPath: nil,
            config: nil,
            scope: nil
        )
        run(request) { [weak self] response in
            guard let self else { return }
            self.isInspecting = false
            if let summary = response.summary {
                self.summary = summary
                self.warnings = response.warnings ?? []
                self.statusMessage = "已识别 \(summary.counts.blocks) 个文档块"
            } else {
                self.statusMessage = "文档已读取，但没有可显示的结构信息"
            }
        }
    }

    func formatDocument() {
        requestFormatting(scope: "all")
    }

    func formatSelectedSection() {
        requestFormatting(scope: selectedSection.rawValue)
    }

    private func requestFormatting(scope: String) {
        guard let inputURL, let outputURL else {
            statusMessage = "请先选择输入文档和输出位置"
            return
        }
        guard isOverwritingInput || !isSameDocument(inputURL, outputURL) else {
            alertMessage = "输出文件不能覆盖输入文档，请选择其他位置。"
            return
        }
        pendingFormatScope = scope
        if FileManager.default.fileExists(atPath: outputURL.path) {
            overwriteURL = outputURL
            return
        }
        performFormatting(scope: scope)
    }

    func confirmOverwrite() {
        guard overwriteURL != nil else { return }
        let scope = pendingFormatScope
        overwriteURL = nil
        performFormatting(scope: scope)
    }

    func revealOutput() {
        guard let outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    func openOutput() {
        guard let outputURL, FileManager.default.fileExists(atPath: outputURL.path) else {
            alertMessage = "排版结果尚未生成。"
            return
        }
        NSWorkspace.shared.open(outputURL)
    }

    func saveConfig() {
        let panel = NSSavePanel()
        panel.title = "保存排版配置"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = configFileURL?.lastPathComponent ?? "paper-format-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try JSONEncoder.pretty.encode(config)
            try data.write(to: url)
            savedConfig = config
            configFileURL = url
            statusMessage = "配置已保存：\(url.lastPathComponent)"
        } catch {
            alertMessage = "保存配置失败：\(error.localizedDescription)"
        }
    }

    func loadConfig() {
        let panel = NSOpenPanel()
        panel.title = "载入排版配置"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            config = try JSONDecoder().decode(FormatterConfig.self, from: data)
            savedConfig = config
            configFileURL = url
            statusMessage = "已载入配置：\(url.lastPathComponent)"
        } catch {
            alertMessage = "载入配置失败：\(error.localizedDescription)"
        }
    }

    func resetAllConfig() {
        config = FormatterConfig()
        statusMessage = "已恢复全部默认规则"
    }

    func resetSelectedConfig() {
        let defaults = FormatterConfig()
        switch selectedSection {
        case .page: config.page = defaults.page
        case .body: config.body = defaults.body
        case .heading1: config.heading1 = defaults.heading1
        case .heading2: config.heading2 = defaults.heading2
        case .heading3: config.heading3 = defaults.heading3
        case .heading4: config.heading4 = defaults.heading4
        case .heading5: config.heading5 = defaults.heading5
        case .heading6: config.heading6 = defaults.heading6
        case .equation: config.equation = defaults.equation
        case .table: config.table = defaults.table
        case .caption: config.caption = defaults.caption
        case .note: config.note = defaults.note
        case .reference: config.reference = defaults.reference
        case .code: config.code = defaults.code
        case .list: config.list = defaults.list
        }
        statusMessage = "已恢复“\(selectedSection.title)”默认规则"
    }

    private func performFormatting(scope: String = "all") {
        guard let inputURL, let outputURL else { return }
        let replacesOriginal = isOverwritingInput
        let engineOutputURL = replacesOriginal
            ? stagedOutputURL(for: inputURL)
            : outputURL
        isFormatting = true
        warnings = []
        if replacesOriginal {
            statusMessage = "正在生成排版结果；原文件暂未移动…"
        } else if scope == "all" {
            statusMessage = "正在应用全部排版规则…"
        } else if let section = FormatterSection(rawValue: scope) {
            statusMessage = "正在排版“\(section.title)”…"
        } else {
            statusMessage = "正在应用排版规则…"
        }
        let request = EngineRequest(
            action: "format",
            engine: selectedEngine.rawValue,
            inputPath: inputURL.path,
            outputPath: engineOutputURL.path,
            config: config,
            scope: scope
        )
        run(request) { [weak self] response in
            guard let self else { return }
            if replacesOriginal {
                guard response.outputPath != nil else {
                    self.discardStagedOutput(at: engineOutputURL)
                    self.isFormatting = false
                    self.statusMessage = "排版结果未生成，原始文档保持不变。"
                    self.alertMessage = "排版引擎没有返回输出文件，已取消覆盖。"
                    return
                }
                self.recycleOriginalAndInstall(
                    stagedOutputURL: engineOutputURL,
                    originalURL: inputURL,
                    response: response,
                    scope: scope
                )
            } else {
                self.finishFormatting(
                    response: response,
                    scope: scope,
                    finalOutputURL: outputURL,
                    replacedOriginal: false
                )
            }
        }
    }

    private func recycleOriginalAndInstall(
        stagedOutputURL: URL,
        originalURL: URL,
        response: EngineResponse,
        scope: String
    ) {
        statusMessage = "排版结果已生成，正在将原文件移入废纸篓…"
        NSWorkspace.shared.recycle([originalURL]) { [weak self] recycledURLs, recycleError in
            DispatchQueue.main.async {
                guard let self else { return }
                if let recycleError {
                    self.discardStagedOutput(at: stagedOutputURL)
                    self.isFormatting = false
                    self.statusMessage = "未覆盖原始文档。"
                    self.alertMessage = "无法将原始文档移入废纸篓，已取消覆盖。\n\(recycleError.localizedDescription)"
                    return
                }

                do {
                    try FileManager.default.moveItem(at: stagedOutputURL, to: originalURL)
                    self.finishFormatting(
                        response: response,
                        scope: scope,
                        finalOutputURL: originalURL,
                        replacedOriginal: true
                    )
                } catch {
                    let recycledURL = recycledURLs[originalURL] ?? recycledURLs.values.first
                    let restored = self.restoreOriginalIfPossible(
                        from: recycledURL,
                        to: originalURL
                    )
                    self.isFormatting = false
                    self.statusMessage = restored
                        ? "未覆盖原始文档，已从废纸篓恢复原文件。"
                        : "未能放入排版结果，原文件仍可在废纸篓中恢复。"
                    self.alertMessage = "排版结果无法替换原始文件。\n\(error.localizedDescription)\n排版结果仍保存在：\n\(stagedOutputURL.path)"
                }
            }
        }
    }

    private func restoreOriginalIfPossible(from recycledURL: URL?, to originalURL: URL) -> Bool {
        guard let recycledURL,
              !FileManager.default.fileExists(atPath: originalURL.path) else { return false }
        do {
            try FileManager.default.moveItem(at: recycledURL, to: originalURL)
            return true
        } catch {
            return false
        }
    }

    private func discardStagedOutput(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func finishFormatting(
        response: EngineResponse,
        scope: String,
        finalOutputURL: URL,
        replacedOriginal: Bool
    ) {
        isFormatting = false
        warnings = response.warnings ?? []
        if let summary = response.summary {
            self.summary.counts = summary.counts
        }
        let outputName = finalOutputURL.lastPathComponent
        hasFormattedCurrentTarget = true
        if replacedOriginal {
            statusMessage = "原文件已移入废纸篓，已生成同名排版文档：\(outputName)"
        } else if scope == "all" {
            statusMessage = "排版完成：\(outputName)"
        } else if let section = FormatterSection(rawValue: scope) {
            statusMessage = "仅\(section.title)排版完成：\(outputName)"
        } else {
            statusMessage = "排版完成：\(outputName)"
        }
        if !warnings.isEmpty {
            statusMessage += "（有 \(warnings.count) 条提示）"
        }
        selectedDestination = .output
    }

    private func isSameDocument(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath().path
            == rhs.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func defaultOutputURL(for inputURL: URL) -> URL {
        inputURL.deletingPathExtension()
            .appendingPathExtension("formatted")
            .appendingPathExtension("docx")
    }

    private func stagedOutputURL(for inputURL: URL) -> URL {
        let filename = inputURL.lastPathComponent
        let stagedName = ".\(filename).formatting-\(UUID().uuidString).docx"
        return inputURL.deletingLastPathComponent().appendingPathComponent(stagedName)
    }

    private func run(_ request: EngineRequest, completion: @escaping (EngineResponse) -> Void) {
        let engine = self.engine
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let response = try engine.send(request)
                DispatchQueue.main.async {
                    completion(response)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isInspecting = false
                    self?.isFormatting = false
                    self?.statusMessage = "操作失败"
                    self?.alertMessage = error.localizedDescription
                }
            }
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
