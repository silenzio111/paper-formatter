import Foundation

struct EngineRequest: Encodable {
    let action: String
    let engine: String?
    let inputPath: String?
    let outputPath: String?
    let config: FormatterConfig?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case action
        case engine
        case inputPath = "input_path"
        case outputPath = "output_path"
        case config
        case scope
    }
}

struct EngineResponse: Decodable {
    let ok: Bool
    let action: String?
    let summary: DocumentSummary?
    let warnings: [String]?
    let outputPath: String?
    let config: FormatterConfig?
    let scope: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case summary
        case warnings
        case outputPath = "output_path"
        case config
        case scope
        case error
    }
}

enum EngineError: LocalizedError {
    case resourceMissing
    case processFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "找不到内置 Python 排版引擎。请确认工程资源完整。"
        case .processFailed(let message):
            return message
        case .invalidResponse:
            return "Python 排版引擎返回了无法识别的结果。"
        }
    }
}

struct PythonEngineClient {
    func send(_ request: EngineRequest) throws -> EngineResponse {
        guard let scriptURL = engineScriptURL() else {
            throw EngineError.resourceMissing
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let python = pythonExecutable()
        process.executableURL = python.executable
        process.arguments = python.arguments + [scriptURL.path]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PYTHONDONTWRITEBYTECODE": "1"]
        ) { _, newValue in newValue }

        do {
            try process.run()
        } catch {
            throw EngineError.processFailed("无法启动 Python。请确认系统已安装 Python 3。\n\(error.localizedDescription)")
        }

        let payload = try JSONEncoder().encode(request)
        inputPipe.fileHandleForWriting.write(payload)
        inputPipe.fileHandleForWriting.write(Data([10]))
        inputPipe.fileHandleForWriting.closeFile()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let response = try? JSONDecoder().decode(EngineResponse.self, from: output) else {
            let diagnostic = String(data: errorOutput, encoding: .utf8) ?? ""
            throw EngineError.processFailed(diagnostic.isEmpty ? "Python 排版引擎没有返回有效结果。" : diagnostic)
        }

        if !response.ok {
            throw EngineError.processFailed(response.error ?? "Python 排版引擎执行失败。")
        }
        if process.terminationStatus != 0 {
            throw EngineError.processFailed("Python 排版引擎异常退出（状态码 \(process.terminationStatus)）。")
        }
        return response
    }

    private func engineScriptURL() -> URL? {
        // A packaged app owns its resources directly; Bundle.module asserts when
        // SwiftPM's separate resource bundle is not present beside the binary.
        if let url = Bundle.main.url(forResource: "formatter_engine", withExtension: "py") {
            return url
        }

        if Bundle.main.bundleURL.pathExtension.lowercased() == "app" {
            return nil
        }

#if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "formatter_engine", withExtension: "py") {
            return url
        }
#endif
        return nil
    }

    private func pythonExecutable() -> (executable: URL, arguments: [String]) {
        let fileManager = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        if let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return (URL(fileURLWithPath: path), [])
        }
        return (URL(fileURLWithPath: "/usr/bin/env"), ["python3"])
    }
}
