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
    }
}
