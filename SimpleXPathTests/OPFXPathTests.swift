//
//  OPFXPathTests.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 3/2/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import XCTest
import SimpleXPath

class OPFXPathTests: XCTestCase {
  
  lazy var opf: XMLDocument! = {
    let b = NSBundle(forClass: AttributeNSXPathTests.self)
    if let url = b.URLForResource("epub", withExtension: "opf"),
      data = NSData(contentsOfURL: url) {
        let doc = XMLDocument(data: data)
        doc?.registerDefaultNamespace("http://www.idpf.org/2007/opf", usingPrefix: "opf")
        return doc
    }
    
    return nil
  }()
  
  func testDocNotNil() {
    XCTAssertTrue(opf != nil, "opf should not be nil")
  }
  
  func testNonRootNS() {
    if let langEl = opf.selectFirstElement("//dc:language") {
      XCTAssertEqual(langEl.content!, "ja", "language should be `ja`")
    } else {
      XCTFail("Couldn't select `//dc:language`")
    }
  }
  
  func testNonElementXPath() {
    XCTAssertTrue(opf.selectElements("//namespace::*") == nil, "selectElements should be nil for `//namespace::*`")
  }
  
}
