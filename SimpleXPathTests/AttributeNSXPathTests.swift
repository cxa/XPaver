//
//  AttributeNSXPathTests.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 2/22/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import SimpleXPath
import XCTest

class AttributeNSXPathTests: XCTestCase {
  
  lazy var attrDoc: XMLDocument! = {
    let b = NSBundle(forClass: AttributeNSXPathTests.self)
    if let url = b.URLForResource("AttributeWithNS", withExtension: "xml"),
      data = NSData(contentsOfURL: url) {
        let doc = XMLDocument(data: data)
        doc?.registerDefaultNamespace("http://www.w3.org", usingPrefix: "w3")
        return doc
    }
    
    return nil
  }()
  
  override func setUp() {
    super.setUp()
    XCTAssertTrue(attrDoc != nil, "attrDoc should not be nil")
  }
  
  func testAttributes() {
    if let good2 = attrDoc.selectFirstElement("/w3:x/w3:good[2]") {
      if let attrs = good2.attributes {
        let expected = ["a": "1"]
        var real = [String: String]()
        for a in attrs {
          real[a.name] = a.value!
        }
        
        XCTAssertEqual(expected, real, "attributes should be `\(expected)`")
      } else {
        XCTFail("could not get attributes for good2")
      }
    } else {
      XCTFail("could not select el by `/w3:x/w3:good[2]`")
    }
  }
  
  func testAttributeValueInNamespace() {
    if let good2 = attrDoc.selectFirstElement("/w3:x/w3:good[2]"){
      if let val = good2.valueForAttribute("a", inNamespace: "http://www.w3.org") {
        XCTAssertEqual(val, "2", "a in http://www.w3.org should be `2`")
      } else {
        XCTFail("could not get b in n1")
      }
    } else {
      XCTFail("could not get attribute value in namespace n1")
    }
  }
  
}
