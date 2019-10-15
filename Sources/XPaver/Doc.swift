//
//  Doc.swift
//  
//
//  Created by CHEN Xian-an on 2019/6/9.
//

import Foundation
import libxml2

public final class Doc: Equatable {
  public enum Kind {
    case xml
    case html
  }

  public enum Error: Swift.Error {
    case invalidSourceData
    case invalidEncoding
    case noXMLRoot
  }

  public let data: Data
  public let kind: Kind
  public let encoding: String.Encoding

  public init(data: Data, kind: Kind, encoding: String.Encoding = .utf8) throws {
    self.data = data
    self.kind = kind
    self.encoding = encoding
    //self.defaultNamespaces = defaultNamespaces
    guard let buf =
      data.withUnsafeBytes({ rbp in rbp.baseAddress?.assumingMemoryBound(to: Int8.self) })
      else { throw Error.invalidSourceData }
    let cfenc = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
    //print(CFStringConvertEncodingToIANACharSetName(cfenc).flatMap { CFStringGetCStringPtr($0, CFStringBuiltInEncodings.UTF8.rawValue) })
    guard
      let iana = CFStringConvertEncodingToIANACharSetName(cfenc) as String?
      else { throw Error.invalidEncoding }
    switch kind {
    case .xml:
      _xmlDoc = xmlReadMemory(buf, Int32(data.count), nil, iana, Int32(XML_PARSE_NOBLANKS.rawValue))
    case .html:
      let opt =
        HTML_PARSE_RECOVER.rawValue |
        HTML_PARSE_NOBLANKS.rawValue |
        HTML_PARSE_NOWARNING.rawValue |
        HTML_PARSE_NOERROR.rawValue
      _xmlDoc = htmlReadMemory(buf, Int32(data.count), nil, iana, Int32(opt))
    }
    _root = xmlDocGetRootElement(_xmlDoc)
    if _root == nil { throw Error.noXMLRoot }
  }

    convenience init(xmlString: String, kind: Kind) throws{
        guard let data = xmlString.data(using: .utf8)else{
            throw Error.invalidSourceData
        }
        try self.init(data: data, kind: kind)
    }
    
  convenience init(
    fileURL: URL,
    readingOptions: Data.ReadingOptions = [],
    kind: Kind, encoding: String.Encoding = .utf8) throws
  {
    do {
      let data = try Data(contentsOf: fileURL, options: readingOptions)
      try self.init(data: data, kind: kind, encoding: encoding)
    } catch (let err) {
      throw err
    }
  }

  deinit {
    xmlFreeDoc(_xmlDoc)
  }

  public static func == (lhs: Doc, rhs: Doc) -> Bool {
    lhs.data == rhs.data &&
    lhs.kind == rhs.kind &&
    lhs.encoding == rhs.encoding &&
    lhs._xmlDoc == rhs._xmlDoc
  }

  // MARK: - Privates
  let _xmlDoc: xmlDocPtr!
  let _root: xmlNodePtr!
  var _defaultNs: (String, String)? = nil
  var _namespaces = [String: String]()
}

// MARK: -
public extension Doc {
  var root: Node {
    Node(_doc: self, _xmlNode: _root)
  }

  func register(namespaceURI uri: String, forPrefix prefix: String) {
    _namespaces[prefix] = uri
  }
}
