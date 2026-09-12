# Paper Formatter

一个面向论文 DOCX 的 macOS 原生排版工具原型。

## 技术结构

- SwiftUI：原生 macOS 工作台、文件选择、规则编辑和状态展示
- Python 3：默认通过 `python-docx` 读取和保存 DOCX，并用 OOXML 扩展处理公式和样式
- JSON：保存可复用的页面和对象排版规则
- 标准输入/输出：Swift 启动内置 Python 引擎并传递 JSON 请求

工程内置两个排版引擎：默认使用 `python-docx` 保存 DOCX，另有标准库 OOXML 自研引擎可切换。App 构建脚本会把 `python-docx`、`lxml` 和相关依赖复制到 Bundle 资源中。

## 运行

```bash
Scripts/build_native_app.sh
open "Word Formatter.app"
```

也可以用 `swift build` 验证 Swift 工程，或在 Xcode 中打开 `Package.swift` 调试。默认的 `python-docx` 引擎依赖随 `.app` 一起打包；如果直接使用 `swift run`，需要先在当前 Python 环境安装 `python-docx`，否则可切换到自研 OOXML 引擎。

## 工作流

1. 选择输入 DOCX。工具会扫描段落、标题、公式、表格、图片、图表题和参考文献。
2. 在左侧选择规则类别，在右侧通过字体下拉菜单调整字体，并设置字号、行距、段前段后、缩进和对齐方式。
3. 点击顶部“开始排版”应用全部规则；也可以在规则页点击“仅排版当前规则”，只处理当前选中的一级标题、公式或其他对象。
4. 默认会另存为 `原文件名.formatted.docx`，原始文件保持不变；如确实需要以原文件名交付，可在“文档”面板开启“覆盖原始 Word 文档”。排版会先生成临时结果，再将原文件移入废纸篓，最后以原文件名放入排版结果；执行前仍有红色二次确认，原文件可从废纸篓恢复。

## 当前识别规则

- 公式：DOCX 中的 `m:oMath` 和 `m:oMathPara`
- 表格：DOCX 中的 `w:tbl`
- 标题：读取 `styles.xml` 中的样式名称、纲目级别，以及保守的中文/数字标题文本模式，支持 1-6 级
- 图表题：`Table 1`、`Figure 1`、`图 1`、`表 1` 等独立题注；会排除“图 4 中，……”、“表 5 揭示了……”这类叙述性正文
- 参考文献：Bibliography/Reference 样式，或编号开头且文本较长的段落
- 图片：含有 Word drawing/picture/object 且没有文字的段落
- 代码块：Pandoc 的 `SourceCode` 段落；代码 token 的颜色和样式会保留
- 列表：段落中的 `w:numPr`；会保留 Word 编号定义和原有缩进

独立公式和行内公式会分开处理：独立公式会重排为居中公式加右侧编号，正文段落仍按正文规则排版，但其中的 `m:oMath` 统一使用 Latin Modern Math 字体。

## 样例预设

默认规则根据 `排版样例与原始导出/未排版例子.docx` 和 `排版样例与原始导出/排版成品样例.docx` 提取：Letter 页面、上下 2.54 cm、左右 3.18 cm、1.15 倍行距、正文首行 24 磅缩进，以及按样式名称复用“三线表”的逻辑。

Pandoc 的样式 ID 可能与表格样式 ID 冲突，例如 `af2` 在原始样例中是“公式”段落样式，在成品样例中是“三线表”表格样式。引擎会读取样式类型并优先复用已有的“三线表”样式；如果输入文档没有该样式，才注入内置模板。

引擎会保留原文档的图片、表格、公式对象、页眉、脚注、尾注和批注部件，仅对识别出的对象写入对应的段落和字符属性。图片形式的公式不会被当作 Office Math 自动识别。

## 配置文件

示例见 `paper-format-config.example.json`。长度单位如下：

- 页面边距：厘米
- 字号、段前、段后、首行缩进：磅
- 行距：倍数，例如 `1.5`
- 对齐：`left`、`center`、`right` 或 `justify`

默认规则使用宋体处理中文正文和表格中文文字，正文拉丁字符使用 Times New Roman，表格拉丁字符和公式使用 Latin Modern Math；公式编号会放在无边框布局的最右侧。三线表优先使用输入文档已有的样式，样式冲突时使用内置的成品样例模板。

后续可以在同一套规则结构上增加页码、题注编号和期刊模板，而不需要改动 SwiftUI 界面和 Python 通信协议。

## 构建 macOS App

项目提供了一个类似原生 macOS 应用的打包脚本。脚本会构建 SwiftUI 界面，把 Python 排版引擎和示例配置复制到 App 资源目录，并生成本地 ad-hoc 签名：

```bash
Scripts/build_native_app.sh
open "Word Formatter.app"
```

生成的应用位于项目根目录。应用需要系统中可执行的 Python 3；脚本会优先查找 `/opt/homebrew/bin/python3`、`/usr/local/bin/python3` 和 `/usr/bin/python3`。构建时会把当前 Python 版本对应的 `python-docx`/`lxml` 依赖打进 App，因此应在目标机器上重新构建 Bundle，避免 Python 小版本和 lxml 二进制不匹配。
