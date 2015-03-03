//
//  XMLDocument.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 2/19/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import libxml2

public enum XMLDocumentType {
  case XML
  case HTML
}

public struct XMLDocument {
  
  public let data: NSData
  
  public let documentType: XMLDocumentType
  
  public let encoding: NSStringEncoding
  
  public let rootElement: XMLElement
  
  public init?(data d: NSData, documentType type: XMLDocumentType = .XML, encoding enc: NSStringEncoding = NSUTF8StringEncoding) {
    data = d
    documentType = type
    encoding = enc
    let buffer = unsafeBitCast(data.bytes, UnsafePointer<Int8>.self)
    let size = Int32(data.length)
    let cfenc = CFStringConvertNSStringEncodingToEncoding(encoding)
    let iana = CFStringConvertEncodingToIANACharSetName(cfenc)
    let ianaChar = (iana as NSString).UTF8String
    switch type {
    case .XML:
      _xmlDoc = xmlReadMemory(buffer, size, nil, ianaChar, Int32(XML_PARSE_NOBLANKS.value))
    case .HTML:
      _xmlDoc = htmlReadMemory(buffer, size, nil, ianaChar, Int32(HTML_PARSE_NOBLANKS.value | HTML_PARSE_NOWARNING.value | HTML_PARSE_NOERROR.value))
    }
    
    let root = xmlDocGetRootElement(_xmlDoc)
    rootElement = XMLElement(_node: root)
    if _xmlDoc == nil || root == nil {
      return nil
    }
  }
  
  public init?(string s: String, documentType type: XMLDocumentType = .XML, encoding enc: NSStringEncoding = NSUTF8StringEncoding) {
    if let data = s.dataUsingEncoding(enc),
       let doc = XMLDocument(data: data, documentType: type, encoding: enc) {
      self = doc
    } else {
      return nil
    }
  }
  
  private let _xmlDoc: xmlDocPtr
  
}

public extension XMLDocument {
  
  func registerDefaultNamespace(namespaceHref: String, usingPrefix prefix: String) {
    xmlNewNs(xmlDocGetRootElement(_xmlDoc), namespaceHref.xmlCharPointer, prefix.xmlCharPointer)
  }
  
}

extension XMLDocument: XPathLocating {
  
  public func selectElements(withXPath: String) -> SequenceOf<XMLElement>? {
    return rootElement.selectElements(withXPath)
  }
  
  public func selectFirstElement(withXPath: String) -> XMLElement? {
    return rootElement.selectFirstElement(withXPath)
  }
  
}

extension XMLDocument: XPathFunctionEvaluating {
  
  public func evaluate(XPathFunction: String) -> XPathFunctionResult? {
    return rootElement.evaluate(XPathFunction)
  }
  
}