import Foundation

struct PageConfig: Codable, Equatable {
    var paperSize = "A4"
    var marginTop = 2.54
    var marginBottom = 2.54
    var marginLeft = 3.18
    var marginRight = 3.18

    enum CodingKeys: String, CodingKey {
        case paperSize = "paper_size"
        case marginTop = "margin_top"
        case marginBottom = "margin_bottom"
        case marginLeft = "margin_left"
        case marginRight = "margin_right"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paperSize = try container.decodeIfPresent(String.self, forKey: .paperSize) ?? "A4"
        marginTop = try container.decodeIfPresent(Double.self, forKey: .marginTop) ?? 2.54
        marginBottom = try container.decodeIfPresent(Double.self, forKey: .marginBottom) ?? 2.54
        marginLeft = try container.decodeIfPresent(Double.self, forKey: .marginLeft) ?? 3.18
        marginRight = try container.decodeIfPresent(Double.self, forKey: .marginRight) ?? 3.18
    }
}

struct ParagraphStyleConfig: Codable, Equatable {
    var fontName = "Times New Roman"
    var latinFontName: String? = nil
    var fontSize = 12.0
    var lineSpacing = 1.15
    var before = 0.0
    var after = 0.0
    var firstLineIndent = 0.0
    var alignment = "left"
    var bold = false
    var italic = false

    enum CodingKeys: String, CodingKey {
        case fontName = "font_name"
        case latinFontName = "latin_font_name"
        case fontSize = "font_size"
        case lineSpacing = "line_spacing"
        case before
        case after
        case firstLineIndent = "first_line_indent"
        case alignment
        case bold
        case italic
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? "Times New Roman"
        latinFontName = try container.decodeIfPresent(String.self, forKey: .latinFontName)
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 12
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 1.15
        before = try container.decodeIfPresent(Double.self, forKey: .before) ?? 0
        after = try container.decodeIfPresent(Double.self, forKey: .after) ?? 0
        firstLineIndent = try container.decodeIfPresent(Double.self, forKey: .firstLineIndent) ?? 0
        alignment = try container.decodeIfPresent(String.self, forKey: .alignment) ?? "left"
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
    }
}

enum FormatterEngine: String, CaseIterable, Codable, Identifiable, Hashable {
    case pythonDocx = "python-docx"
    case nativeOOXML = "native-ooxml"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pythonDocx:
            return "python-docx"
        case .nativeOOXML:
            return "自研 OOXML"
        }
    }

    var detail: String {
        switch self {
        case .pythonDocx:
            return "默认，使用 python-docx 保存 Word 文档"
        case .nativeOOXML:
            return "保留当前标准库 OOXML 排版引擎"
        }
    }
    
}

struct FormatterConfig: Codable, Equatable {
    var page = PageConfig()
    var body = ParagraphStyleConfig()
    var heading1 = ParagraphStyleConfig()
    var heading2 = ParagraphStyleConfig()
    var heading3 = ParagraphStyleConfig()
    var heading4 = ParagraphStyleConfig()
    var heading5 = ParagraphStyleConfig()
    var heading6 = ParagraphStyleConfig()
    var equation = ParagraphStyleConfig()
    var table = TableConfig()
    var caption = ParagraphStyleConfig()
    var note = ParagraphStyleConfig()
    var reference = ParagraphStyleConfig()
    var code = ParagraphStyleConfig()
    var list = ParagraphStyleConfig()

    init() {
        page.paperSize = "LETTER"
        page.marginTop = 2.54
        page.marginBottom = 2.54
        page.marginLeft = 3.18
        page.marginRight = 3.18
        body = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 12,
            lineSpacing: 1.15,
            before: 9,
            after: 9,
            firstLineIndent: 24,
            alignment: "justify",
            bold: false,
            italic: false
        )
        heading1 = ParagraphStyleConfig(
            fontName: "黑体",
            fontSize: 20,
            lineSpacing: 1.15,
            before: 18,
            after: 4,
            firstLineIndent: 0,
            alignment: "center",
            bold: true,
            italic: false
        )
        heading2 = ParagraphStyleConfig(
            fontName: "黑体",
            fontSize: 16,
            lineSpacing: 1.15,
            before: 36,
            after: 0,
            firstLineIndent: 0,
            alignment: "center",
            bold: true,
            italic: false
        )
        heading3 = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 14,
            lineSpacing: 1.15,
            before: 6,
            after: 0,
            firstLineIndent: 0,
            alignment: "left",
            bold: true,
            italic: false
        )
        heading4 = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 12,
            lineSpacing: 1.15,
            before: 4,
            after: 2,
            firstLineIndent: 0,
            alignment: "left",
            bold: true,
            italic: false
        )
        heading5 = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 11,
            lineSpacing: 1.15,
            before: 4,
            after: 2,
            firstLineIndent: 0,
            alignment: "left",
            bold: true,
            italic: false
        )
        heading6 = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 10,
            lineSpacing: 1.15,
            before: 2,
            after: 0,
            firstLineIndent: 0,
            alignment: "left",
            bold: true,
            italic: false
        )
        equation = ParagraphStyleConfig(
            fontName: "Latin Modern Math",
            fontSize: 11,
            lineSpacing: 1.15,
            before: 9,
            after: 9,
            firstLineIndent: 0,
            alignment: "center",
            bold: false,
            italic: false
        )
        caption = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 10,
            lineSpacing: 1.15,
            before: 0,
            after: 4,
            firstLineIndent: 0,
            alignment: "center",
            bold: true,
            italic: false
        )
        note = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 10,
            lineSpacing: 1.0,
            before: 0,
            after: 4,
            firstLineIndent: 0,
            alignment: "left",
            bold: false,
            italic: false
        )
        reference = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 12,
            lineSpacing: 1.15,
            before: 9,
            after: 9,
            firstLineIndent: 0,
            alignment: "left",
            bold: false,
            italic: false
        )
        code = ParagraphStyleConfig(
            fontName: "Menlo",
            fontSize: 9,
            lineSpacing: 1,
            before: 4,
            after: 4,
            firstLineIndent: 0,
            alignment: "left",
            bold: false,
            italic: false
        )
        list = ParagraphStyleConfig(
            fontName: "宋体",
            fontSize: 12,
            lineSpacing: 1.15,
            before: 0,
            after: 0,
            firstLineIndent: 0,
            alignment: "left",
            bold: false,
            italic: false
        )
        body.latinFontName = "Times New Roman"
        note.latinFontName = "Times New Roman"
        reference.latinFontName = "Times New Roman"
    }

    enum CodingKeys: String, CodingKey {
        case page
        case body
        case heading1
        case heading2
        case heading3
        case heading4
        case heading5
        case heading6
        case equation
        case table
        case caption
        case note
        case reference
        case code
        case list
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FormatterConfig()
        page = try container.decodeIfPresent(PageConfig.self, forKey: .page) ?? defaults.page
        body = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .body) ?? defaults.body
        heading1 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading1) ?? defaults.heading1
        heading2 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading2) ?? defaults.heading2
        heading3 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading3) ?? defaults.heading3
        heading4 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading4) ?? defaults.heading4
        heading5 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading5) ?? defaults.heading5
        heading6 = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .heading6) ?? defaults.heading6
        equation = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .equation) ?? defaults.equation
        table = try container.decodeIfPresent(TableConfig.self, forKey: .table) ?? defaults.table
        caption = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .caption) ?? defaults.caption
        note = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .note) ?? defaults.note
        reference = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .reference) ?? defaults.reference
        code = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .code) ?? defaults.code
        list = try container.decodeIfPresent(ParagraphStyleConfig.self, forKey: .list) ?? defaults.list
    }
}

extension ParagraphStyleConfig {
    init(
        fontName: String,
        fontSize: Double,
        lineSpacing: Double,
        before: Double,
        after: Double,
        firstLineIndent: Double,
        alignment: String,
        bold: Bool,
        italic: Bool,
        latinFontName: String? = nil
    ) {
        self.fontName = fontName
        self.latinFontName = latinFontName
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.before = before
        self.after = after
        self.firstLineIndent = firstLineIndent
        self.alignment = alignment
        self.bold = bold
        self.italic = italic
    }
}

struct TableConfig: Codable, Equatable {
    var fontName = "宋体"
    var latinFontName = "Latin Modern Math"
    var fontSize = 9.0
    var lineSpacing = 1.5
    var before = 0.0
    var after = 0.0
    var firstLineIndent = 0.0
    var alignment = "center"
    var bold = false
    var italic = false
    var styleID = "af2"
    var widthMode = "percentage"
    var widthPercent = 100.0
    var autoWidthMaxColumns = 3
    var paragraphStyleID = "Compact"
    var headerBold = true

    enum CodingKeys: String, CodingKey {
        case fontName = "font_name"
        case latinFontName = "latin_font_name"
        case fontSize = "font_size"
        case lineSpacing = "line_spacing"
        case before
        case after
        case firstLineIndent = "first_line_indent"
        case alignment
        case bold
        case italic
        case styleID = "style_id"
        case widthMode = "width_mode"
        case widthPercent = "width_percent"
        case autoWidthMaxColumns = "auto_width_max_columns"
        case paragraphStyleID = "paragraph_style_id"
        case headerBold = "header_bold"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? "宋体"
        latinFontName = try container.decodeIfPresent(String.self, forKey: .latinFontName) ?? "Latin Modern Math"
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 9
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 1.5
        before = try container.decodeIfPresent(Double.self, forKey: .before) ?? 0
        after = try container.decodeIfPresent(Double.self, forKey: .after) ?? 0
        firstLineIndent = try container.decodeIfPresent(Double.self, forKey: .firstLineIndent) ?? 0
        alignment = try container.decodeIfPresent(String.self, forKey: .alignment) ?? "center"
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        styleID = try container.decodeIfPresent(String.self, forKey: .styleID) ?? "af2"
        widthMode = try container.decodeIfPresent(String.self, forKey: .widthMode) ?? "auto_by_columns"
        widthPercent = try container.decodeIfPresent(Double.self, forKey: .widthPercent) ?? 100
        autoWidthMaxColumns = try container.decodeIfPresent(Int.self, forKey: .autoWidthMaxColumns) ?? 3
        paragraphStyleID = try container.decodeIfPresent(String.self, forKey: .paragraphStyleID) ?? "Compact"
        headerBold = try container.decodeIfPresent(Bool.self, forKey: .headerBold) ?? true
    }
}

struct DetectedItem: Codable, Identifiable {
    let type: String
    let label: String
    let text: String

    var id: String { "\(type)-\(label)-\(text)" }
}

struct DocumentCounts: Codable {
    var paragraphs = 0
    var tables = 0
    var equations = 0
    var images = 0
    var headings = 0
    var captions = 0
    var notes = 0
    var references = 0
    var codeBlocks = 0
    var lists = 0
    var blocks = 0
    var formatted = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let object = try container.decode([String: Int].self)
        paragraphs = object["paragraphs"] ?? 0
        tables = object["tables"] ?? 0
        equations = object["equations"] ?? 0
        images = object["images"] ?? 0
        headings = object["headings"] ?? 0
        captions = object["captions"] ?? 0
        notes = object["notes"] ?? 0
        references = object["references"] ?? 0
        codeBlocks = object["code_blocks"] ?? 0
        lists = object["lists"] ?? 0
        blocks = object["blocks"] ?? 0
        formatted = object["formatted"] ?? 0
    }
}

struct DocumentSummary: Codable {
    var counts = DocumentCounts()
    var samples: [DetectedItem] = []
}

enum FormatterSection: String, CaseIterable, Identifiable, Hashable {
    case page
    case body
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case equation
    case table
    case caption
    case note
    case reference
    case code
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .page: return "页面"
        case .body: return "正文"
        case .heading1: return "一级标题"
        case .heading2: return "二级标题"
        case .heading3: return "三级标题"
        case .heading4: return "四级标题"
        case .heading5: return "五级标题"
        case .heading6: return "六级标题"
        case .equation: return "公式"
        case .table: return "表格"
        case .caption: return "图表题"
        case .note: return "图表注"
        case .reference: return "参考文献"
        case .code: return "代码块"
        case .list: return "列表"
        }
    }

    var icon: String {
        switch self {
        case .page: return "doc.plaintext"
        case .body: return "text.alignleft"
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return "textformat.size"
        case .equation: return "function"
        case .table: return "tablecells"
        case .caption: return "text.below.photo"
        case .note: return "text.alignleft"
        case .reference: return "books.vertical"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .list: return "list.number"
        }
    }
}

enum WorkspaceDestination: String, CaseIterable, Identifiable, Hashable {
    case overview
    case page
    case body
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case equation
    case table
    case caption
    case note
    case reference
    case code
    case list
    case output

    var id: String { rawValue }

    var ruleSection: FormatterSection? {
        guard self != .overview, self != .output else { return nil }
        return FormatterSection(rawValue: rawValue)
    }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .output: return "输出结果"
        default: return ruleSection?.title ?? rawValue
        }
    }

    var icon: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .output: return "checkmark.circle"
        default: return ruleSection?.icon ?? "circle"
        }
    }

    static var ruleDestinations: [WorkspaceDestination] {
        allCases.filter { $0.ruleSection != nil }
    }
}
