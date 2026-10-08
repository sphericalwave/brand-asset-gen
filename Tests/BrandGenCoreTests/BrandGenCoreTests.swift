import XCTest
import AppKit
@testable import BrandGenCore

final class BrandGenCoreTests: XCTestCase {

    func testAppIconContentsJSONIsValidAndCoversLadder() throws {
        let data = Data(appIconContentsJSON.utf8)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = obj?["images"] as? [[String: Any]]
        XCTAssertEqual(images?.count, 11)
        XCTAssertTrue(images?.contains { $0["platform"] as? String == "ios" && $0["size"] as? String == "1024x1024" } ?? false)
    }

    func testColorsetJSONSingleColor() throws {
        let json = colorsetJSON(lightHex: "2A0A3D")
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let colors = obj?["colors"] as? [[String: Any]]
        XCTAssertEqual(colors?.count, 1)
        XCTAssertTrue(json.contains(#""red": "0x2A""#))
        XCTAssertTrue(json.contains(#""blue": "0x3D""#))
    }

    func testColorsetJSONHandlesHashPrefixAndDarkVariant() throws {
        let json = colorsetJSON(lightHex: "#FF0000", darkHex: "00FF00")
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let colors = obj?["colors"] as? [[String: Any]]
        XCTAssertEqual(colors?.count, 2)
    }

    func testRenderProducesDecodablePNGAtRequestedSize() throws {
        let data = render(size: 64, background: .black, glyphDrawer: { _, _ in })
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, 64)
        XCTAssertEqual(rep.pixelsHigh, 64)
        XCTAssertFalse(rep.hasAlpha, "App Store rejects app icons with an alpha channel")
    }

    /// A back-layer overlay PDF can fade its own hidden lines (e.g. the far edges of a
    /// vector equilibrium); tinting must keep that per-shape alpha, not flatten it to opaque.
    func testTintedOverlayKeepsPerShapeAlpha() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("overlay-\(UUID()).pdf")
        var box = CGRect(x: 0, y: 0, width: 100, height: 100)
        let pdf = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        pdf.beginPDFPage(nil)
        pdf.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        pdf.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
        pdf.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
        pdf.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        pdf.endPDFPage()
        pdf.closePDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let data = renderImage(width: 100, height: 100, drawer: pdfGlyphDrawer(url: url, tint: .white, scale: 1))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        let front = try XCTUnwrap(rep.colorAt(x: 25, y: 50))
        let back  = try XCTUnwrap(rep.colorAt(x: 75, y: 50))
        XCTAssertEqual(front.alphaComponent, 1, accuracy: 0.02)
        XCTAssertEqual(back.alphaComponent, 0.4, accuracy: 0.02)
        XCTAssertEqual(back.redComponent, 1, accuracy: 0.02, "tinted white")
    }

    func testLaunchLogoWithoutNameIsSquare() throws {
        let drawer = shadowed(tiled(layered([{ r, c in c.setFillColor(.white); c.fill(r) }])))
        let data = renderLaunchLogo(circleSize: 100, appName: "", glyphDrawer: drawer)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, 100)
        XCTAssertEqual(rep.pixelsHigh, 100)
    }
}
