#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSlot {
    let name: String
    let pixels: Int
}

let slots = [
    IconSlot(name: "icon_16x16.png", pixels: 16),
    IconSlot(name: "icon_16x16@2x.png", pixels: 32),
    IconSlot(name: "icon_32x32.png", pixels: 32),
    IconSlot(name: "icon_32x32@2x.png", pixels: 64),
    IconSlot(name: "icon_128x128.png", pixels: 128),
    IconSlot(name: "icon_128x128@2x.png", pixels: 256),
    IconSlot(name: "icon_256x256.png", pixels: 256),
    IconSlot(name: "icon_256x256@2x.png", pixels: 512),
    IconSlot(name: "icon_512x512.png", pixels: 512),
    IconSlot(name: "icon_512x512@2x.png", pixels: 1024)
]

let outputPath = CommandLine.arguments.dropFirst().first ?? "NativeApp/WordFormatter.iconset"
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

func scaled(_ value: CGFloat, _ size: CGFloat) -> CGFloat {
    value / 1024.0 * size
}

let sourceURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("WordFormatterIconSource.png")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("找不到生图图标源文件：\(sourceURL.path)")
}

func drawIcon(size pixelSize: Int) -> NSImage {
    let dimension = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    NSColor.clear.setFill()
    canvas.fill()

    NSGraphicsContext.saveGraphicsState()
    // Clip the generated square to a native app-icon shape so generated
    // background pixels cannot leave black corners in Finder or the Dock.
    let maskRect = canvas.insetBy(dx: scaled(20, dimension), dy: scaled(20, dimension))
    let maskPath = NSBezierPath(
        roundedRect: maskRect,
        xRadius: scaled(205, dimension),
        yRadius: scaled(205, dimension)
    )
    maskPath.addClip()
    sourceImage.draw(
        in: canvas,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "WordFormatterIcon", code: 1)
    }
    try pngData.write(to: url)
}

for slot in slots {
    try writePNG(drawIcon(size: slot.pixels), to: outputURL.appendingPathComponent(slot.name))
}

print(outputURL.path)
