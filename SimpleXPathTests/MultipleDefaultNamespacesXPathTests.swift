//
//  MultipleDefaultNamespacesXPathTests.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 2/22/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import SimpleXPath
import XCTest

class MultipleDefaultNamespacesXPathTests: XCTestCase {
  
  lazy var nestedNSDoc: XMLDocument! = {
    let b = NSBundle(forClass: MultipleDefaultNamespacesXPathTests.self)
    if let url = b.URLForResource("MultipleDefaultNamespaces", withExtension: "xml"),
      data = NSData(contentsOfURL: url) {
        let doc = XMLDocument(data: data)
        doc?.registerDefaultNamespace("http://www.your.example.com/xml/person", usingPrefix: "person")
        doc?.registerDefaultNamespace("http://www.my.example.com/xml/cities", usingPrefix: "cities")
        return doc
    }
    
    return nil
  }()
  
  override func setUp() {
    super.setUp()
    XCTAssertTrue(nestedNSDoc != nil, "doc should not be nil")
  }
  
  func testNestedNamespaces() {
    if let homecity = nestedNSDoc.selectFirstElement("/person:person/cities:homecity") {
      if let name = homecity.selectFirstElement("./cities:name") {
        XCTAssertEqual(name.tag!, "name", "tag should be `name`")
        XCTAssertEqual(name.content!, "London", "name content should be `London`")
      } else {
        XCTFail("could not select el by `./cities:name`")
      }
    } else {
      XCTFail("could not select el by `/person:person/person:homecity`")
    }
  }
  
}
