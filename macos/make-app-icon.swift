#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "\(FileManager.default.currentDirectoryPath)/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
let size = NSSize(width: 1024, height: 1024)

let image = NSImage(size: size)
image.lockFocus()

let canvasRect = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1).setFill()
canvasRect.fill()

let outerRect = NSRect(x: 56, y: 56, width: 912, height: 912)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 220, yRadius: 220)
NSGraphicsContext.current?.saveGraphicsState()
outerPath.addClip()

let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.19, green: 0.21, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1),
])!
backgroundGradient.draw(in: outerRect, angle: -35)

let boardRect = NSRect(x: 128, y: 168, width: 520, height: 600)
let boardPath = NSBezierPath(roundedRect: boardRect, xRadius: 86, yRadius: 86)
let boardGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.86, alpha: 1),
    NSColor(calibratedRed: 0.56, green: 0.59, blue: 0.63, alpha: 1),
])!
boardGradient.draw(in: boardPath, angle: -25)
NSColor.white.withAlphaComponent(0.26).setStroke()
boardPath.lineWidth = 3
boardPath.stroke()

func drawKey(_ rect: NSRect, colors: [NSColor], title: String, subtitle: String? = nil, highlight: Bool = false) {
    let shell = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
    let shellGradient = NSGradient(colors: colors)!
    shellGradient.draw(in: shell, angle: -45)

    if highlight {
        NSColor(calibratedRed: 0.23, green: 0.83, blue: 1.00, alpha: 0.95).setStroke()
        shell.lineWidth = 5
        shell.stroke()
    } else {
        NSColor.white.withAlphaComponent(0.08).setStroke()
        shell.lineWidth = 2
        shell.stroke()
    }

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 27, weight: .bold),
        .foregroundColor: colors.first!.brightnessComponent > 0.7 ? NSColor.black.withAlphaComponent(0.78) : NSColor.white.withAlphaComponent(0.95),
        .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
        }(),
    ]

    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: colors.first!.brightnessComponent > 0.7 ? NSColor.black.withAlphaComponent(0.52) : NSColor.white.withAlphaComponent(0.68),
        .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
        }(),
    ]

    let titleRect = NSRect(x: rect.minX + 10, y: rect.midY - 8, width: rect.width - 20, height: 56)
    title.draw(in: titleRect, withAttributes: titleAttributes)

    if let subtitle {
        let subtitleRect = NSRect(x: rect.minX + 10, y: rect.minY + 16, width: rect.width - 20, height: 22)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
    }
}

let keyOriginX = boardRect.minX + 40
let topY = boardRect.maxY - 150
let keyW: CGFloat = 86
let keyH: CGFloat = 92
let gap: CGFloat = 14
let darkKey = [NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.31, alpha: 1), NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.15, alpha: 1)]
let lightKey = [NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.96, alpha: 1), NSColor(calibratedRed: 0.83, green: 0.87, blue: 0.88, alpha: 1)]
let redKey = [NSColor(calibratedRed: 0.96, green: 0.35, blue: 0.41, alpha: 1), NSColor(calibratedRed: 0.72, green: 0.16, blue: 0.24, alpha: 1)]

drawKey(NSRect(x: keyOriginX, y: topY, width: keyW, height: keyH), colors: darkKey, title: "SMART\nINSERT", subtitle: "F9", highlight: true)
drawKey(NSRect(x: keyOriginX + keyW + gap, y: topY, width: keyW, height: keyH), colors: darkKey, title: "APPEND", subtitle: "SHIFT+F12")
drawKey(NSRect(x: keyOriginX + 2 * (keyW + gap), y: topY, width: keyW, height: keyH), colors: darkKey, title: "RIPPLE", subtitle: "SHIFT+F10")

drawKey(NSRect(x: keyOriginX + 172, y: topY - 134, width: keyW, height: keyH), colors: darkKey, title: "COPY", subtitle: "CMD+C")
drawKey(NSRect(x: keyOriginX + 172 + keyW + gap, y: topY - 134, width: keyW, height: keyH), colors: darkKey, title: "PASTE", subtitle: "CMD+V")
drawKey(NSRect(x: keyOriginX + 172 + 2 * (keyW + gap), y: topY - 134, width: keyW, height: keyH), colors: redKey, title: "CUT", subtitle: "CMD+X")

drawKey(NSRect(x: keyOriginX, y: boardRect.minY + 224, width: keyW * 1.5 + gap / 2, height: keyH), colors: lightKey, title: "IN", subtitle: "I")
drawKey(NSRect(x: keyOriginX + keyW * 1.5 + gap * 1.5, y: boardRect.minY + 224, width: keyW * 1.5 + gap / 2, height: keyH), colors: lightKey, title: "OUT", subtitle: "O")

drawKey(NSRect(x: keyOriginX, y: boardRect.minY + 116, width: keyW, height: keyH), colors: darkKey, title: "TRIM IN", subtitle: "SHIFT+Y")
drawKey(NSRect(x: keyOriginX + keyW + gap, y: boardRect.minY + 116, width: keyW, height: keyH), colors: darkKey, title: "TRIM OUT", subtitle: "SHIFT+U")
drawKey(NSRect(x: keyOriginX + 2 * (keyW + gap), y: boardRect.minY + 116, width: keyW, height: keyH), colors: darkKey, title: "MARKER", subtitle: "M")

drawKey(NSRect(x: keyOriginX + 172, y: boardRect.minY + 20, width: 250, height: 84), colors: darkKey, title: "STOP/PLAY", subtitle: "SPACE")

let sourceRect = NSRect(x: boardRect.maxX - 148, y: topY, width: 108, height: 92)
let timelineRect = NSRect(x: boardRect.maxX - 148, y: topY - 108, width: 108, height: 92)
drawKey(sourceRect, colors: darkKey, title: "SOURCE", subtitle: "CTRL+3")
drawKey(timelineRect, colors: darkKey, title: "TIMELINE", subtitle: "CTRL+4")

let wheelRect = NSRect(x: 712, y: 250, width: 208, height: 208)
let wheelPath = NSBezierPath(ovalIn: wheelRect)
let wheelGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.06, alpha: 1),
])!
wheelGradient.draw(in: wheelPath, relativeCenterPosition: NSZeroPoint)
NSColor.white.withAlphaComponent(0.06).setStroke()
wheelPath.lineWidth = 3
wheelPath.stroke()

let hubRect = NSRect(x: wheelRect.minX + 36, y: wheelRect.maxY - 94, width: 72, height: 72)
let hubPath = NSBezierPath(ovalIn: hubRect)
NSColor.white.withAlphaComponent(0.10).setFill()
hubPath.fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 54, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.94),
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.66),
]

"DiSE".draw(at: NSPoint(x: 698, y: 620), withAttributes: titleAttributes)
"Resolve board programmer".draw(at: NSPoint(x: 700, y: 588), withAttributes: subtitleAttributes)

let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.78),
]
"J1".draw(at: NSPoint(x: wheelRect.midX - 18, y: wheelRect.midY - 8), withAttributes: footerAttributes)

NSGraphicsContext.current?.restoreGraphicsState()
image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0])
else {
    fputs("Failed to render icon.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
try pngData.write(to: outputURL)

private extension NSColor {
    var brightnessComponent: CGFloat {
        guard let rgb = usingColorSpace(.deviceRGB) else {
            return 0
        }
        return (rgb.redComponent * 0.299) + (rgb.greenComponent * 0.587) + (rgb.blueComponent * 0.114)
    }
}
