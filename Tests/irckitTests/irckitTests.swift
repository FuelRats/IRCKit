import XCTest
@testable import irckit

final class irckitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(irckit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
