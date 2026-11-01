import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

// Renders the Wedgie app icon at 1024×1024 and produces a full iconset + .icns
// using Apple's iconutil.

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("build")
let iconsetDir = outputDir.appendingPathComponent("Wedgie.iconset")
let icnsPath = outputDir.appendingPathComponent("Wedgie.icns")
let masterPNG = outputDir.appendingPathComponent("Wedgie-1024.png")

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// MARK: - Icon design

private struct IconView: View {
    var body: some View {
        ZStack {
            // Cool dark background gradient — sets a tech, premium feel.
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.10, blue: 0.12),
                            Color(red: 0.04, green: 0.03, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle rim highlight at the top edge.
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.10),
                            .white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )

            Scene()
                .padding(120)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// Side-view of a MacBook with the lid tilted open, mirroring the menubar
/// icon. A brass bead — the same one used on the drag cord — sits in the
/// gap between lid and base as the literal wedge holding the lid open.
private struct Scene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let baseWidth: CGFloat = w * 0.93
            let baseHeight: CGFloat = h * 0.085
            let baseX: CGFloat = (w - baseWidth) / 2
            let baseY: CGFloat = h * 0.80

            let lidLength: CGFloat = baseWidth * 0.98
            let lidThickness: CGFloat = h * 0.075
            let openAngleDeg: CGFloat = 28           // SwiftUI positive = CW visually
            let openAngleRad = openAngleDeg * .pi / 180

            let hingeX = baseX + baseWidth
            let hingeY = baseY

            // ----- Bead geometry -----
            // Bigger bead, positioned slightly inside the geometric "fit" point
            // so the lid actually overlaps its top — gives an "in between"
            // (rather than "in front of") read.
            let beadDiameter: CGFloat = h * 0.25
            let geometricFit = beadDiameter / tan(openAngleRad)
            let distFromHinge = geometricFit * 0.92
            let beadCenterX = hingeX - distFromHinge
            let beadCenterY = baseY - beadDiameter / 2

            // ----- Floor shadow -----
            Ellipse()
                .fill(Color.black.opacity(0.65))
                .frame(width: baseWidth * 0.95, height: baseHeight * 0.75)
                .blur(radius: 34)
                .position(x: baseX + baseWidth / 2, y: baseY + baseHeight + h * 0.045)

            // ----- Base slab -----
            slab(width: baseWidth, height: baseHeight)
                .position(x: baseX + baseWidth / 2, y: baseY + baseHeight / 2)

            // ----- Bead (drawn BEFORE lid so lid covers its top sliver) -----
            BrassBead()
                .frame(width: beadDiameter, height: beadDiameter)
                .shadow(color: .black.opacity(0.7), radius: 16, x: 5, y: 12)
                .position(x: beadCenterX, y: beadCenterY)

            // ----- Lid slab — hinged at bottom-right corner of base top -----
            slab(width: lidLength, height: lidThickness)
                .rotationEffect(.degrees(openAngleDeg), anchor: .bottomTrailing)
                .position(
                    x: hingeX - lidLength / 2,
                    y: hingeY - lidThickness / 2
                )
                .shadow(color: .black.opacity(0.5), radius: 18, x: 4, y: 14)
        }
    }

    private func slab(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.28, style: .continuous)
            .fill(bodyGradient)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 3)
                    .padding(.horizontal, 18)
                    .offset(y: -height / 2 + 2.5)
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 3.5)
                    .padding(.horizontal, 18)
                    .offset(y: height / 2 - 2.5)
                    .blur(radius: 1)
            )
            .frame(width: width, height: height)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.48, green: 0.48, blue: 0.51),
                Color(red: 0.26, green: 0.26, blue: 0.29),
                Color(red: 0.11, green: 0.11, blue: 0.13)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Reusable brass-bead view — same look as the cord-knot in the drag UI.
private struct BrassBead: View {
    var body: some View {
        ZStack {
            // Outer dark ring for definition.
            Circle()
                .fill(Color(red: 0.12, green: 0.08, blue: 0.03))

            // Brass body gradient.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.91, blue: 0.62),
                            Color(red: 0.85, green: 0.62, blue: 0.22),
                            Color(red: 0.36, green: 0.22, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(4)

            // Specular crescent in the top-left quadrant.
            Circle()
                .fill(Color.white.opacity(0.55))
                .padding(28)
                .offset(x: -16, y: -16)
                .blur(radius: 10)

            // Subtle inner ring.
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 1.5)
                .padding(6)
        }
    }
}

// MARK: - Render

@MainActor
func render() throws {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1.0
    renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)

    guard let cgImage = renderer.cgImage else {
        throw NSError(domain: "WedgieIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "renderer.cgImage was nil"])
    }

    // Save master 1024 PNG.
    try savePNG(cgImage, to: masterPNG, width: 1024, height: 1024)

    // Build the iconset at all required sizes.
    let entries: [(name: String, size: Int)] = [
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

    for entry in entries {
        let dest = iconsetDir.appendingPathComponent(entry.name)
        try savePNG(cgImage, to: dest, width: entry.size, height: entry.size)
    }

    // Convert iconset -> .icns via iconutil.
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
    try proc.run()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else {
        throw NSError(
            domain: "WedgieIcon",
            code: Int(proc.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
        )
    }

    print("==> Wrote \(masterPNG.path)")
    print("==> Wrote \(icnsPath.path)")
}

private func savePNG(_ source: CGImage, to url: URL, width: Int, height: Int) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "WedgieIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "CGContext init failed"])
    }
    ctx.interpolationQuality = .high
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let scaled = ctx.makeImage() else {
        throw NSError(domain: "WedgieIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "makeImage failed"])
    }

    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "WedgieIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "CGImageDestination init failed"])
    }
    CGImageDestinationAddImage(dest, scaled, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "WedgieIcon", code: 5, userInfo: [NSLocalizedDescriptionKey: "destination finalize failed"])
    }
}

MainActor.assumeIsolated {
    do {
        try render()
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }
}
