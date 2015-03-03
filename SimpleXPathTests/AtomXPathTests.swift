//
//  AtomXPathTests.swift
//  SimpleXPathTests
//
//  Created by CHEN Xian’an on 2/19/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import SimpleXPath
import XCTest

class AtomXPathTests: XCTestCase {
  
  lazy var atomDoc: XMLDocument! = {
    let b = NSBundle(forClass: AtomXPathTests.self)
    if let url = b.URLForResource("atom", withExtension: "xml"),
       let data = NSData(contentsOfURL: url)
    {
      let doc = XMLDocument(data: data)
      doc?.registerDefaultNamespace("http://www.w3.org/2005/Atom", usingPrefix: "atom")
      return doc
    }
    
    return nil
    }()
  
  
  override func setUp() {
    super.setUp()
    XCTAssertTrue(atomDoc != nil, "atomDoc should not be nil")
  }
  
  func testSearchingForDefaultNamespace() {
    if let els = atomDoc?.selectElements("/atom:feed/atom:entry/atom:link") {
      var i = 0
      for el in els {
        XCTAssertEqual(el.tag!, "link", "tag should be `link`")
        i++
      }
      
      XCTAssertEqual(i, 3, "links count should be 3")
    } else {
      XCTFail("could not select els by `/atom:feed/atom:entry/atom:link`")
    }
  }
  
  func testSearchingForGivenNamespace() {
    if let els = atomDoc?.selectElements("/atom:feed/atom:entry/dc:language") {
      var i = 0
      for el in els {
        XCTAssertEqual(el.tag!, "language", "tag should be `language`")
        XCTAssertEqual(el.content!, "en-us", "el content should be `en-us`")
        i++
      }
      
      XCTAssertEqual(i, 1, "languages count should be 1")
    } else {
      XCTFail("could not select els by `/atom:feed/atom:entry/dc:language`")
    }
  }
  
  func testNonRootElement() {
    if let entry = atomDoc?.selectFirstElement("/atom:feed/atom:entry[1]") {
      if let name = entry.selectFirstElement("./atom:author/atom:name") {
        XCTAssertEqual(name.tag!, "name", "tag should be `name`")
      } else {
        XCTFail("could not select el by `./atom:author/atom:name`")
      }
    } else {
      XCTFail("could not select el by `/atom:feed/atom:entry[1]`")
    }
  }
  
  func testAttributes() {
    if let link2 = atomDoc?.selectFirstElement("/atom:feed/atom:entry/atom:link[2]") {
      if let attrs = link2.attributes {
        let expected = ["rel": "alternate", "type": "text/html", "href": "http://example.org/2003/12/13/atom03.html"]
        var real = [String: String]()
        for a in attrs {
          real[a.name] = a.value!
        }
        
        XCTAssertEqual(expected, real, "attributes should be `\(expected)`")
        XCTAssertEqual(link2.valueForAttribue("rel")!, "alternate", "value for rel should be `alternate`")
      } else {
        XCTFail("could not get attributes for link2")
      }
    } else {
      XCTFail("could not select el by `/atom:feed/atom:entry/atom:link[2]`")
    }
  }
  
  func testNumericFunctionResult() {
    if let result = atomDoc?.evaluate("count(/atom:feed/atom:entry/atom:link)") {
      switch result {
      case .double(let c):
        XCTAssertEqual(c, 3, "link count should be 3")
      default:
        XCTFail("wrong result type")
      }
    } else {
      XCTFail("could not eval function for count(/atom:feed/atom:entry/atom:link)")
    }
  }
  
  func testStringFunctionResult() {
    if let result = atomDoc?.evaluate("string(/atom:feed/atom:entry/dc:language[1])") {
      switch result {
      case .string(let s):
        XCTAssertEqual(s, "en-us", "dc:language text shoud be `en-us`")
      default:
        XCTFail("wrong result type")
      }
    } else {
      XCTFail("could not eval function for string(/atom:feed/atom:entry/dc:language[1])")
    }
  }
  
  func testBooleanFunctionResult() {
    if let result = atomDoc?.evaluate("boolean(/atom:feed/atom:entry/dc:language[1][.='en-us'])") {
      switch result {
      case .bool(let b):
        XCTAssertEqual(b, true, "dc:language text shoud be `en-us`")
      default:
        XCTFail("wrong result type")
      }
    } else {
      XCTFail("could not eval function for boolean(/atom:feed/atom:entry/dc:language[1][.='en-us'])")
    }
  }
  
}
