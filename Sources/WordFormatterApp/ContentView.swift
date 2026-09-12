import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let documentURLs = urls.filter { $0.pathExtension.lowercased() == "docx" }
        guard !documentURLs.isEmpty else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .wordFormatterOpenDocuments,
                object: documentURLs
            )
        }
    }
}

extension Notification.Name {
    static let wordFormatterOpenDocuments = Notification.Name("WordFormatterOpenDocuments")
}

@main
struct WordFormatterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Word Formatter", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("打开 DOCX…") {
                    model.chooseInputDocument()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("重新分析") {
                    model.inspectDocument()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("开始排版") {
                    model.formatDocument()
                }
                .keyboardShortcut(.defaultAction)
            }
            CommandMenu("配置") {
                Button("载入配置…") {
                    model.loadConfig()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])
                Button("保存配置…") {
                    model.saveConfig()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                Divider()
                Button("恢复当前规则默认值") {
                    model.resetSelectedConfig()
                }
                Button("恢复全部默认值") {
                    model.resetAllConfig()
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            WorkbenchView()
        }
        .frame(minWidth: 960, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: .wordFormatterOpenDocuments)) { notification in
            guard let urls = notification.object as? [URL], let url = urls.first else { return }
            model.loadInputDocument(url)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
            loadDroppedDocument(providers)
        }
        .overlay {
            if model.isDropTargeted {
                DropTargetOverlay()
                    .allowsHitTesting(false)
            }
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("确定") { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
        .confirmationDialog(
            model.overwriteConfirmationTitle,
            isPresented: Binding(
                get: { model.overwriteURL != nil },
                set: { if !$0 { model.overwriteURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(model.overwriteConfirmationButtonTitle, role: .destructive) {
                model.confirmOverwrite()
            }
            Button("取消", role: .cancel) {
                model.overwriteURL = nil
            }
        } message: {
            Text(model.overwriteConfirmationMessage)
        }
    }

    private func loadDroppedDocument(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSURL.self) { object, _ in
            guard let nsURL = object as? NSURL else { return }
            let url = nsURL as URL
            DispatchQueue.main.async {
                model.loadInputDocument(url)
            }
        }
        return true
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("论文排版工作台")
                        .font(.headline)
                    Text("论文 Word 排版工具")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)

            List(selection: $model.selectedDestination) {
                Section("工作流") {
                    SidebarDestinationRow(destination: .overview)
                }

                Section("排版规则") {
                    ForEach(WorkspaceDestination.ruleDestinations) { destination in
                        SidebarDestinationRow(destination: destination)
                    }
                }

                Section("结果") {
                    SidebarDestinationRow(destination: .output)
                }
            }
            .listStyle(.sidebar)
            .onChange(of: model.selectedDestination) { destination in
                if let section = destination.ruleSection {
                    model.selectedSection = section
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.inputURL == nil ? Color.secondary.opacity(0.35) : Color.green)
                        .frame(width: 7, height: 7)
                    Text(model.inputURL == nil ? "未选择文档" : "文档已载入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if model.hasUnsavedConfigChanges {
                    Label("配置有未保存修改", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SidebarDestinationRow: View {
    let destination: WorkspaceDestination

    var body: some View {
        Label(destination.title, systemImage: destination.icon)
            .tag(destination)
    }
}

private struct WorkbenchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchToolbar()
            Divider()

            ScrollView {
                Group {
                    switch model.selectedDestination {
                    case .overview:
                        OverviewView()
                    case .output:
                        OutputView()
                    default:
                        RuleEditorView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(26)
            }

            Divider()
            WorkbenchStatusBar()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct WorkbenchToolbar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: model.inputURL == nil ? "doc" : "doc.fill")
                    .foregroundStyle(model.inputURL == nil ? Color.secondary : Color.blue)
                Text(model.inputURL?.lastPathComponent ?? "未选择文档")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.inputURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 120, maxWidth: 235, alignment: .leading)

            Button {
                model.chooseInputDocument()
            } label: {
                Label("打开 DOCX", systemImage: "folder")
            }
            .help("选择需要排版的 Word 文档")

            HStack(spacing: 7) {
                Text("引擎")
                    .font(.subheadline.weight(.medium))
                    .fixedSize()
                Picker("排版引擎", selection: Binding(
                    get: { model.selectedEngine },
                    set: { model.engineChanged($0) }
                )) {
                    ForEach(FormatterEngine.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
                .help(model.selectedEngine.detail)
            }

            Spacer(minLength: 8)

            Button {
                model.inspectDocument()
            } label: {
                Label("重新分析", systemImage: "arrow.clockwise")
            }
            .disabled(model.inputURL == nil || model.isInspecting || model.isFormatting)

            Button {
                model.formatDocument()
            } label: {
                Label("开始排版", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canFormat)

            if model.isInspecting || model.isFormatting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct WorkbenchStatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            if model.hasUnsavedConfigChanges {
                Label("配置未保存", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if model.outputExists {
                Label("已有输出文件", systemImage: "doc.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusColor: Color {
        if model.isInspecting || model.isFormatting {
            return .orange
        }
        if model.inputURL == nil {
            return Color.secondary.opacity(0.35)
        }
        return .green
    }
}

private struct PageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DropTargetOverlay: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.92)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.blue)
                Text("释放以载入 DOCX")
                    .font(.title3.weight(.semibold))
                Text("只支持 Word .docx 文档")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(12)
        }
        .padding(20)
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(
                title: "文档概览",
                subtitle: "导入 DOCX 后先确认识别结果，再调整规则并输出排版文件。"
            )
            DocumentPanel()
            if model.inputURL == nil {
                EmptyDocumentState()
            } else {
                StructurePanel()
            }
        }
    }
}

private struct EmptyDocumentState: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("等待载入文档")
                    .font(.headline)
                Text("选择或拖入 DOCX 后，这里会显示文档结构统计。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 18)
    }
}

private struct DocumentPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PanelContainer {
            PanelHeader(
                title: "文档",
                subtitle: "默认另存为新 DOCX；也可主动选择覆盖原始文档"
            )

            VStack(spacing: 12) {
                FilePathRow(
                    label: "输入文档",
                    url: model.inputURL,
                    placeholder: "尚未选择 .docx 文件",
                    buttonTitle: "选择文档",
                    buttonIcon: "folder",
                    action: model.chooseInputDocument,
                    showsAction: false
                )
                if model.inputURL != nil {
                    Toggle(
                        isOn: Binding(
                            get: { model.shouldOverwriteInput },
                            set: { model.setOverwriteInput($0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("覆盖原始 Word 文档")
                                .font(.subheadline.weight(.medium))
                            Text("开启后原文件会移入废纸篓，再由同名排版结果替代。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.red)
                    .disabled(model.isInspecting || model.isFormatting)

                    if model.isOverwritingInput {
                        FilePathRow(
                            label: "覆盖目标",
                            url: model.outputURL,
                            placeholder: "原始文档",
                            buttonTitle: "",
                            buttonIcon: "",
                            action: {},
                            showsAction: false
                        )
                        Label("原文件会移入废纸篓，可在废纸篓中恢复。", systemImage: "trash.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        FilePathRow(
                            label: "输出位置",
                            url: model.outputURL,
                            placeholder: "选择排版结果的保存位置",
                            buttonTitle: "选择位置",
                            buttonIcon: "square.and.arrow.down",
                            action: model.chooseOutputDocument
                        )
                        .disabled(model.isInspecting || model.isFormatting)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("拖放 DOCX 到窗口")
                        .font(.subheadline.weight(.medium))
                    Text("也可以使用顶部的“打开 DOCX”选择文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )

            Divider()

            HStack(spacing: 10) {
                Image(systemName: model.isOverwritingInput ? "exclamationmark.triangle.fill" : (model.outputExists ? "doc.checkmark" : "info.circle"))
                    .foregroundStyle(model.isOverwritingInput ? .red : (model.outputExists ? .orange : .secondary))
                Text(model.isOverwritingInput
                     ? "已选择覆盖原始文档，原文件将先移入废纸篓。"
                     : (model.outputExists
                        ? "输出文件已存在，开始排版时会先确认是否覆盖。"
                        : "输出文件名会随输入文档自动刷新。"))
                    .font(.caption)
                    .foregroundStyle(model.isOverwritingInput ? .red : .secondary)
                Spacer()

                if model.canOpenOutput {
                    Button {
                        model.openOutput()
                    } label: {
                        Label("打开结果", systemImage: "arrow.up.right.square")
                    }
                    .disabled(model.isFormatting)
                }
            }
        }
    }
}

private struct FilePathRow: View {
    let label: String
    let url: URL?
    let placeholder: String
    let buttonTitle: String
    let buttonIcon: String
    let action: () -> Void
    var showsAction = true

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(width: 76, alignment: .leading)
            HStack(spacing: 8) {
                Image(systemName: url == nil ? "doc" : "doc.fill")
                    .foregroundStyle(url == nil ? Color.secondary : Color.blue)
                Text(url?.path ?? placeholder)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(url == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            if showsAction {
                Button(action: action) {
                    Label(buttonTitle, systemImage: buttonIcon)
                }
                .controlSize(.regular)
            }
        }
    }
}

private struct StructurePanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PanelContainer {
            PanelHeader(
                title: "结构识别",
                subtitle: "解析 OOXML 原生结构，公式和表格不会被当作普通正文处理"
            )

            let counts = model.summary.counts
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 110), spacing: 10), count: 4),
                spacing: 10
            ) {
                SummaryMetric(title: "段落", value: counts.paragraphs, icon: "text.alignleft")
                SummaryMetric(title: "公式", value: counts.equations, icon: "function")
                SummaryMetric(title: "表格", value: counts.tables, icon: "tablecells")
                SummaryMetric(title: "图片", value: counts.images, icon: "photo")
                SummaryMetric(title: "标题", value: counts.headings, icon: "textformat.size")
                SummaryMetric(title: "图表题", value: counts.captions, icon: "text.below.photo")
                SummaryMetric(title: "图表注", value: counts.notes, icon: "text.alignleft")
                SummaryMetric(title: "参考文献", value: counts.references, icon: "books.vertical")
                SummaryMetric(title: "代码块", value: counts.codeBlocks, icon: "chevron.left.forwardslash.chevron.right")
                SummaryMetric(title: "列表", value: counts.lists, icon: "list.number")
                SummaryMetric(title: "文档块", value: counts.blocks, icon: "square.stack.3d.up")
            }

            if !model.summary.samples.isEmpty {
                Divider()
                Text("最近识别对象")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(model.summary.samples) { item in
                        HStack(spacing: 10) {
                            Text(item.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.blue)
                                .frame(width: 72, alignment: .leading)
                            Text(item.text.isEmpty ? "无文本内容" : item.text)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        )
    }
}

private struct OutputView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(
                title: "输出结果",
                subtitle: model.isOverwritingInput
                    ? "当前目标是原始文档；执行前会要求确认覆盖。"
                    : "查看当前输出文件，必要时可以打开文档或在 Finder 中定位。"
            )

            if let outputURL = model.outputURL {
                PanelContainer {
                    PanelHeader(
                        title: model.isOverwritingInput
                            ? (model.hasFormattedCurrentTarget ? "原始文档已覆盖" : "将覆盖原始文档")
                            : (model.outputExists ? "排版文件已生成" : "输出文件"),
                        subtitle: model.isOverwritingInput
                            ? (model.hasFormattedCurrentTarget
                                ? "当前文件就是已排版后的原始文档。"
                                : "原文件会先移入废纸篓，再以同名排版结果替代。")
                            : (model.outputExists ? "排版完成后原始文档保持不变。" : "排版结果尚未生成。")
                    )

                    FilePathRow(
                        label: model.isOverwritingInput ? "覆盖目标" : "输出位置",
                        url: outputURL,
                        placeholder: "选择排版结果的保存位置",
                        buttonTitle: "更改位置",
                        buttonIcon: "folder",
                        action: model.chooseOutputDocument,
                        showsAction: !model.isOverwritingInput
                    )

                    HStack(spacing: 10) {
                        Image(systemName: model.isOverwritingInput && !model.hasFormattedCurrentTarget
                            ? "exclamationmark.triangle.fill"
                            : (model.canOpenOutput ? "checkmark.circle.fill" : "clock"))
                            .foregroundStyle(model.isOverwritingInput && !model.hasFormattedCurrentTarget
                                ? .red
                                : (model.canOpenOutput ? .green : .secondary))
                        Text(model.isOverwritingInput && !model.hasFormattedCurrentTarget
                            ? "确认后原文件会移入废纸篓。"
                            : (model.canOpenOutput ? "文件可以打开或交付。" : "点击顶部“开始排版”生成文件。"))
                            .font(.subheadline)
                            .foregroundStyle(model.isOverwritingInput && !model.hasFormattedCurrentTarget ? .red : .secondary)
                        Spacer()
                        if model.canOpenOutput {
                            Button {
                                model.revealOutput()
                            } label: {
                                Label("在 Finder 中显示", systemImage: "finder")
                            }
                            Button {
                                model.openOutput()
                            } label: {
                                Label("打开结果", systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if !model.warnings.isEmpty {
                    PanelContainer {
                        PanelHeader(
                            title: "排版提示",
                            subtitle: "以下内容不会阻止文件生成，但建议在交付前检查。"
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(model.warnings.enumerated()), id: \.offset) { entry in
                                Label(entry.element, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } else {
                PanelContainer {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("尚未选择输出文件")
                            .font(.headline)
                        Text("载入 DOCX 后，默认输出位置会自动设置为原文所在文件夹。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
        }
    }
}

private struct RuleEditorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(
                title: "排版规则 · \(model.selectedSection.title)",
                subtitle: "修改当前规则后可以保存为 JSON，在不同文档之间复用。"
            )

            HStack(spacing: 10) {
                Label("当前规则：\(model.selectedSection.title)", systemImage: model.selectedSection.icon)
                    .font(.subheadline.weight(.medium))

                Spacer(minLength: 12)

                if model.hasUnsavedConfigChanges {
                    Label("未保存", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    model.formatSelectedSection()
                } label: {
                    Label("仅排版当前规则", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canFormat)
                .help("只应用当前选中的规则，其他文档内容保持原样")

                Button {
                    model.resetSelectedConfig()
                } label: {
                    Label("恢复当前规则", systemImage: "arrow.counterclockwise")
                }

                Menu {
                    Button {
                        model.loadConfig()
                    } label: {
                        Label("载入配置…", systemImage: "folder")
                    }
                    Button {
                        model.saveConfig()
                    } label: {
                        Label("保存配置…", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button {
                        model.resetAllConfig()
                    } label: {
                        Label("恢复全部默认值", systemImage: "arrow.counterclockwise.circle")
                    }
                } label: {
                    Label("配置", systemImage: "slider.horizontal.3")
                }
            }

            if let configURL = model.configFileURL {
                Label("配置文件：\(configURL.lastPathComponent)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("规则说明")
                        .font(.headline)
                    Text(ruleDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Label("修改会立即应用到下一次排版", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 190, alignment: .leading)

                Divider()

                Group {
                    if model.selectedSection == .page {
                        PageEditor(config: $model.config.page)
                    } else if model.selectedSection == .table {
                        TableEditor(config: $model.config.table)
                    } else {
                        StyleEditor(
                            section: model.selectedSection,
                            style: styleBinding(for: model.selectedSection)
                        )
                    }
                }
                .frame(maxWidth: 720, alignment: .topLeading)

                Spacer(minLength: 0)
            }
        }
    }

    private func styleBinding(for section: FormatterSection) -> Binding<ParagraphStyleConfig> {
        switch section {
        case .body: return $model.config.body
        case .heading1: return $model.config.heading1
        case .heading2: return $model.config.heading2
        case .heading3: return $model.config.heading3
        case .heading4: return $model.config.heading4
        case .heading5: return $model.config.heading5
        case .heading6: return $model.config.heading6
        case .equation: return $model.config.equation
        case .caption: return $model.config.caption
        case .note: return $model.config.note
        case .reference: return $model.config.reference
        case .code: return $model.config.code
        case .list: return $model.config.list
        case .page, .table: return $model.config.body
        }
    }

    private var ruleDescription: String {
        switch model.selectedSection {
        case .page: return "纸张尺寸和页边距会写入文档的每个节。"
        case .body: return "未识别为标题、公式、表格或其他特殊对象的普通段落。"
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            return "依据 Word 标题样式、纲目级别和文本模式识别。"
        case .equation: return "只作用于 Office Math 公式段落，公式编号单独处理。"
        case .table: return "控制三线表、单元格字体、字号、行距和宽度规则。"
        case .caption: return "控制图题和表题的独立字体、字号、间距与对齐。"
        case .note: return "控制图注、表注、来源说明等注释段落。"
        case .reference: return "控制参考文献编号、悬挂缩进和中英文混排字体。"
        case .code: return "控制代码块的等宽字体与段落间距。"
        case .list: return "控制带有 Word 编号定义的列表段落。"
        }
    }
}

private struct PageEditor: View {
    @Binding var config: PageConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EditorTitle(title: "页面设置", detail: "单位为厘米。排版时会写入每个节的页面属性。")

            Form {
                Section("纸张") {
                    Picker("纸张大小", selection: $config.paperSize) {
                        Text("A4").tag("A4")
                        Text("Letter").tag("LETTER")
                    }
                    .pickerStyle(.segmented)
                }
                Section("页边距") {
                    MeasurementField(label: "上", value: $config.marginTop)
                    MeasurementField(label: "下", value: $config.marginBottom)
                    MeasurementField(label: "左", value: $config.marginLeft)
                    MeasurementField(label: "右", value: $config.marginRight)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.horizontal, 4)
    }
}

private enum FontCatalog {
    static let inherited = "跟随中文字体"

    static let recommended = [
        "宋体",
        "黑体",
        "微软雅黑",
        "楷体",
        "仿宋",
        "等线",
        "PingFang SC",
        "Hiragino Sans GB",
        "Noto Sans CJK SC",
        "Times New Roman",
        "Arial",
        "Calibri",
        "Cambria",
        "Helvetica",
        "Georgia",
        "Menlo",
        "Courier New",
        "Latin Modern Math",
        "Cambria Math",
        "STIX Two Math",
    ]

    static func options(current: String, includeInherited: Bool) -> [String] {
        let installed = NSFontManager.shared.availableFontFamilies
        let recommendedSet = Set(recommended)
        let installedOnly = installed
            .filter { !recommendedSet.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        var names = recommended + installedOnly
        if includeInherited {
            names.insert(inherited, at: 0)
        }

        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCurrent.isEmpty && !names.contains(trimmedCurrent) {
            names.insert(trimmedCurrent, at: includeInherited ? 1 : 0)
        }
        return names
    }
}

private struct FontPicker: View {
    let title: String
    @Binding var selection: String
    var includeInherited = false

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(
                FontCatalog.options(current: selection, includeInherited: includeInherited),
                id: \.self
            ) { fontName in
                Text(fontName).tag(fontName)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct StyleEditor: View {
    let section: FormatterSection
    @Binding var style: ParagraphStyleConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EditorTitle(title: "\(section.title)样式", detail: description)

            Form {
                Section("字符") {
                    FontPicker(title: "中文/东亚字体", selection: $style.fontName)
                    FontPicker(
                        title: "西文字体",
                        selection: latinFontSelection,
                        includeInherited: true
                    )
                    Text("从下拉菜单选择已安装字体；西文字体也可以选择跟随中文字体。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("字号")
                        Spacer()
                        TextField("字号", value: $style.fontSize, format: .number)
                            .frame(width: 82)
                        Text("磅")
                            .foregroundStyle(.secondary)
                    }
                    Toggle("粗体", isOn: $style.bold)
                    Toggle("斜体", isOn: $style.italic)
                }

                Section("段落") {
                    HStack {
                        Text("行距")
                        Spacer()
                        TextField("行距", value: $style.lineSpacing, format: .number)
                            .frame(width: 82)
                        Text("倍")
                            .foregroundStyle(.secondary)
                    }
                    MeasurementField(label: "段前", value: $style.before, suffix: "磅")
                    MeasurementField(label: "段后", value: $style.after, suffix: "磅")
                    MeasurementField(label: "首行缩进", value: $style.firstLineIndent, suffix: "磅")
                    Picker("对齐方式", selection: $style.alignment) {
                        Text("保持").tag("preserve")
                        Text("左对齐").tag("left")
                        Text("居中").tag("center")
                        Text("右对齐").tag("right")
                        Text("两端对齐").tag("justify")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.horizontal, 4)
    }

    private var latinFontSelection: Binding<String> {
        Binding(
            get: { style.latinFontName ?? FontCatalog.inherited },
            set: { value in
                style.latinFontName = value == FontCatalog.inherited ? nil : value
            }
        )
    }

    private var description: String {
        switch section {
        case .body: return "应用于未被识别为特殊对象的普通段落。"
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return "按 Word 标题样式、纲目级别和文本模式识别。"
        case .equation: return "只作用于 Office Math 公式段落，不会套用正文格式。"
        case .table: return "作用于表格单元格中的文字和段落。"
        case .caption: return "识别 Table、Figure、图、表等图表题文本。"
        case .note: return "识别注：、资料来源：、Note:、Source: 等表注和图注文本。"
        case .reference: return "识别参考文献样式或编号开头的文献段落。"
        case .code: return "识别 Source Code 段落，保留代码语法颜色并使用等宽字体。"
        case .list: return "识别带有 Word 编号定义的列表，保留原有列表缩进。"
        case .page: return ""
        }
    }
}

private struct TableEditor: View {
    @Binding var config: TableConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EditorTitle(title: "表格样式", detail: "默认适配成品样例的三线表和宽度规则。样式 ID 冲突时引擎会自动回退到兼容样式。")

            Form {
                Section("字符") {
                    FontPicker(title: "中文/东亚字体", selection: $config.fontName)
                    FontPicker(title: "西文字体", selection: $config.latinFontName)
                    Text("从下拉菜单选择已安装字体；默认英文、数字及单元格内公式使用 Latin Modern Math。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("字号")
                        Spacer()
                        TextField("字号", value: $config.fontSize, format: .number)
                            .frame(width: 82)
                        Text("磅")
                            .foregroundStyle(.secondary)
                    }
                    Toggle("表头加粗", isOn: $config.headerBold)
                }

                Section("表格结构") {
                    TextField("表格样式 ID", text: $config.styleID)
                    TextField("单元格段落样式", text: $config.paragraphStyleID)
                    Picker("宽度规则", selection: $config.widthMode) {
                        Text("按列数自动").tag("auto_by_columns")
                        Text("固定百分比").tag("percentage")
                        Text("自动宽度").tag("auto")
                        Text("保留原值").tag("preserve")
                    }
                    .pickerStyle(.segmented)
                    if config.widthMode == "percentage" || config.widthMode == "auto_by_columns" {
                        MeasurementField(label: "固定宽度", value: $config.widthPercent, suffix: "%")
                    }
                    if config.widthMode == "auto_by_columns" {
                        HStack {
                            Text("自动宽度列数上限")
                            Spacer()
                            TextField("列数", value: $config.autoWidthMaxColumns, format: .number)
                                .frame(width: 82)
                        }
                    }
                }

                Section("段落") {
                    Text("表格行距默认 1.5 倍，可按学校模板调整。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("行距")
                        Spacer()
                        TextField("行距", value: $config.lineSpacing, format: .number)
                            .frame(width: 82)
                        Text("倍")
                            .foregroundStyle(.secondary)
                    }
                    Picker("对齐方式", selection: $config.alignment) {
                        Text("左对齐").tag("left")
                        Text("居中").tag("center")
                        Text("右对齐").tag("right")
                        Text("两端对齐").tag("justify")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.horizontal, 4)
    }
}

private struct MeasurementField: View {
    let label: String
    @Binding var value: Double
    var suffix = "厘米"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .frame(width: 82)
            Text(suffix)
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .leading)
        }
    }
}

private struct PanelContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
        )
    }
}

private struct PanelHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EditorTitle: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
