import XCTest
@testable import XPaver

final class XPaverTests: XCTestCase {
  lazy var xmlDoc = try! Doc(fileURL: Self.assetURL(forName: "xml.xml"), kind: .xml)
  lazy var mnsXmlDoc = try! Doc(fileURL: Self.assetURL(forName: "multiple-default-ns.xml"), kind: .xml)
  lazy var htmlDoc = try! Doc(fileURL: Self.assetURL(forName: "html.html"), kind: .html)
  lazy var xmlStrDoc = try! Doc(xmlString: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><note><to>Tove</to><from>Jani</from><heading>Reminder</heading><body>Don't forget me this weekend!</body></note>", kind: .xml)
  
  func testTag() {
    XCTAssertEqual(xmlDoc.root.tag, "package")
    XCTAssertEqual(htmlDoc.root.tag, "html")
    XCTAssertEqual(xmlStrDoc.root.tag, "note")
  }
  
  func testSelect() {
    let cNodes = xmlDoc.root.select(xpath: "//dc:contributor")
    XCTAssertEqual(cNodes.count, 6)
    let pNodes = htmlDoc.root.select(xpath: "//p")
    XCTAssertEqual(pNodes.count, 2)
    let span = pNodes.first?.first(xpath: "./span")
    XCTAssertNotNil(span)
  }
  
  func testFirst() {
    let hnode = htmlDoc.root.first(xpath: "/html/head/title")
    XCTAssertNotNil(hnode)
    let xnode = xmlDoc.root.first(xpath: "/package/metadata/dc:title")
    XCTAssertNotNil(xnode)
  }
  
  func testTagName() {
    let hnode = htmlDoc.root.first(xpath: "/html/head/title")
    XCTAssertEqual(hnode?.tag, "title")
    let xnode = xmlDoc.root.first(xpath: "/package/metadata/dc:title")
    XCTAssertEqual(xnode?.tag, "title")
  }
  
  func testContent() {
    let cNode = xmlDoc.root.first(xpath: "//dc:contributor")
    XCTAssertEqual(cNode?.content, "O’Reilly Production Services")
    let pNode = htmlDoc.root.first(xpath: "//p")
    XCTAssertEqual(pNode?.content, "Hello, World")
  }
  
  func testRawContent() {
    let cNode = xmlDoc.root.first(xpath: "//dc:contributor")
    XCTAssertEqual(cNode?.rawContent, "<dc:contributor>O’Reilly Production Services</dc:contributor>")
    let pNode = htmlDoc.root.first(xpath: "//p")
    XCTAssertEqual(pNode?.rawContent, #"<p class="foo" id="bar"><span>Hello, World</span></p>"#)
  }
  
  func testInnerRawContent() {
    let cNode = xmlDoc.root.first(xpath: "//dc:contributor")
    XCTAssertEqual(cNode?.innerRawContent, "O’Reilly Production Services")
    let pNode = htmlDoc.root.first(xpath: "//p")
    XCTAssertEqual(pNode?.innerRawContent, "<span>Hello, World</span>")
  }
  
  func testParent() {
    let cNode = xmlDoc.root.first(xpath: "//dc:contributor")
    XCTAssertEqual(cNode?.parent?.tag, "metadata")
  }
  
  func testChildNodes() {
    XCTAssertEqual(xmlDoc.root.childNodes.map(Array.init)?.count, 3)
    XCTAssertEqual(htmlDoc.root.childNodes.map(Array.init)?.count, 2)
    XCTAssertEqual(xmlStrDoc.root.childNodes.map(Array.init)?.count, 4)
  }
  
  func testFirstNode() {
    XCTAssertEqual(xmlDoc.root.firstNode?.tag, "metadata")
    XCTAssertEqual(htmlDoc.root.firstNode?.tag, "head")
    XCTAssertEqual(xmlStrDoc.root.firstNode?.tag, "to")
  }
  
  func testChildNodeAt() {
    XCTAssertEqual(xmlDoc.root.childNode(at: 1)?.tag, "manifest")
    XCTAssertEqual(htmlDoc.root.childNode(at: 1)?.tag, "body")
    XCTAssertEqual(xmlStrDoc.root.childNode(at: 1)?.tag, "from")
  }
  
  func testPrev() {
    XCTAssertEqual(xmlDoc.root.childNode(at: 1)?.prev, xmlDoc.root.firstNode)
    XCTAssertEqual(htmlDoc.root.childNode(at: 1)?.prev, htmlDoc.root.firstNode)
    XCTAssertEqual(xmlStrDoc.root.childNode(at: 1)?.prev, xmlStrDoc.root.firstNode)
  }
  
  func testNext() {
    XCTAssertEqual(xmlDoc.root.childNode(at: 0)?.next, xmlDoc.root.childNode(at: 1))
    XCTAssertEqual(htmlDoc.root.childNode(at: 0)?.next, htmlDoc.root.childNode(at: 1))
    XCTAssertEqual(xmlStrDoc.root.childNode(at: 0)?.next, xmlStrDoc.root.childNode(at: 1))
  }
  
  func testAttributes() {
    let xattr = xmlDoc.root.first(xpath: "//dc:title")?.attributes?.first { _ in true }
    XCTAssertEqual(xattr?.name, "id")
    XCTAssertEqual(xattr?.value, "pub-title")
    let hattr = htmlDoc.root.first(xpath: "//p")?.attributes.map(Array.init)
    XCTAssertEqual(hattr?.count, 2)
    XCTAssertEqual(hattr?[0].name, "class")
    XCTAssertEqual(hattr?[0].value, "foo")
    XCTAssertEqual(hattr?[1].name, "id")
    XCTAssertEqual(hattr?[1].value, "bar")
  }
  
  func testAttributeValue() {
    let p = htmlDoc.root.first(xpath: "//p")
    XCTAssertEqual(p?.value(forAttribute: "class"), "foo")
    XCTAssertEqual(p?.value(forAttribute: "id"), "bar")
    let id = xmlDoc.root.first(xpath: "//dc:identifier")
    XCTAssertEqual(id?.value(forAttribute: "id"), "pub-identifier")
    XCTAssertEqual(id?.value(forAttribute: "mock:id"), "mock")
  }
  
  func testMultipleDefaultNamespaces() {
    mnsXmlDoc.register(namespaceURI: "http://www.your.example.com/xml/person", forPrefix: "p")
    mnsXmlDoc.register(namespaceURI: "http://www.my.example.com/xml/cities", forPrefix: "c")
    let cityName = mnsXmlDoc.root.first(xpath: "/p:person/c:homecity/c:name")
    XCTAssertNotNil(cityName)
    XCTAssertEqual(cityName?.content, "London")
  }
  
  func testEval() {
    var result = htmlDoc.root.eval(expr: "count(//p)")
    XCTAssertEqual(result, .double(2))
    result = htmlDoc.root.eval(expr: "string(//p[1])")
    XCTAssertEqual(result, .string("Hello, World"))
    result = htmlDoc.root.eval(expr: "boolean(//p[1][.='Hello, World'])")
    XCTAssertEqual(result, .bool(true))
  }
  
  private static func assetURL(forName name: String) -> URL {
    URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("assets/\(name)")
  }
  
  // I don't what to do with this, test only work in Xcode right now
  
  //  static var allTests = [
  //    ("testTag", testTag),
  //  ]
}
