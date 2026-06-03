#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate_app_icon.swift <output.iconset>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    let data = try makeIconPNG(pixels: iconFile.pixels)
    try data.write(to: outputURL.appendingPathComponent(iconFile.name))
}

private func makeIconPNG(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.bitmapCreationFailed
    }

    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    rect.fill()

    let inset = CGFloat(pixels) * 0.06
    let backgroundRect = rect.insetBy(dx: inset, dy: inset)
    let background = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: CGFloat(pixels) * 0.18,
        yRadius: CGFloat(pixels) * 0.18
    )
    NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.18, alpha: 1).setFill()
    background.fill()

    let innerRect = backgroundRect.insetBy(dx: CGFloat(pixels) * 0.15, dy: CGFloat(pixels) * 0.15)
    drawViewfinder(in: innerRect, pixels: CGFloat(pixels))
    drawTextLines(in: innerRect, pixels: CGFloat(pixels))

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw IconError.pngCreationFailed
    }
    return png
}

private func drawViewfinder(in rect: NSRect, pixels: CGFloat) {
    let path = NSBezierPath()
    let corner = pixels * 0.15
    let lineWidth = max(1, pixels * 0.045)

    path.move(to: NSPoint(x: rect.minX, y: rect.minY + corner))
    path.line(to: NSPoint(x: rect.minX, y: rect.minY))
    path.line(to: NSPoint(x: rect.minX + corner, y: rect.minY))

    path.move(to: NSPoint(x: rect.maxX - corner, y: rect.minY))
    path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
    path.line(to: NSPoint(x: rect.maxX, y: rect.minY + corner))

    path.move(to: NSPoint(x: rect.maxX, y: rect.maxY - corner))
    path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
    path.line(to: NSPoint(x: rect.maxX - corner, y: rect.maxY))

    path.move(to: NSPoint(x: rect.minX + corner, y: rect.maxY))
    path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
    path.line(to: NSPoint(x: rect.minX, y: rect.maxY - corner))

    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.74, alpha: 1).setStroke()
    path.stroke()
}

private func drawTextLines(in rect: NSRect, pixels: CGFloat) {
    let lineWidth = max(1, pixels * 0.035)
    let lineHeight = max(1, pixels * 0.035)
    let lineRadius = lineHeight / 2
    let startY = rect.midY - pixels * 0.11
    let widths = [0.64, 0.48, 0.58]

    for (index, widthScale) in widths.enumerated() {
        let width = rect.width * widthScale
        let y = startY + CGFloat(index) * pixels * 0.115
        let lineRect = NSRect(x: rect.midX - width / 2, y: y, width: width, height: lineHeight)
        let path = NSBezierPath(roundedRect: lineRect, xRadius: lineRadius, yRadius: lineRadius)
        NSColor.white.withAlphaComponent(index == 0 ? 0.95 : 0.75).setFill()
        path.fill()
    }

    let ocr = "OCR" as NSString
    let fontSize = max(7, pixels * 0.17)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    let size = ocr.size(withAttributes: attrs)
    let textRect = NSRect(x: rect.midX - size.width / 2, y: rect.midY + pixels * 0.18, width: size.width, height: size.height)
    ocr.draw(in: textRect, withAttributes: attrs)

    _ = lineWidth
}

private enum IconError: Error {
    case bitmapCreationFailed
    case pngCreationFailed
}
