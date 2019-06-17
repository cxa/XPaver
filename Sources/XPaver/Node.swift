//
//  Node.swift
//  
//
//  Created by CHEN Xian-an on 2019/6/9.
//

import Foundation
import libxml2

public struct Node: Equatable {
  public typealias Attribute = (name: String, value: String?) // name will contain ns prefix e.g. `nsprefix:name` if available

  public enum EvalResult: Equatable {
    case bool(Bool)
    case double(Double)
    case string(String)
  }

  public static func == (lhs: Node, rhs: Node) -> Bool {
    lhs._doc == rhs._doc && lhs._xmlNode == rhs._xmlNode
  }
  
  let _doc: Doc
  let _xmlNode: xmlNodePtr
}


public extension Node {

  // MARK: - Node Info
  /// tag name
  var tag: String? {
    _toStr(_xmlNode.pointee.name)
  }

  /// text content
  var content: String? {
    _toStr(xmlNodeGetContent(_xmlNode))
  }

  /// raw content, node self included
  var rawContent: String? {
    if _xmlNode.pointee.type == XML_TEXT_NODE { return content }
    guard let buf = xmlBufferCreate() else { return nil }
    //defer { xmlBufferFree(buf) }
    let size =
      _doc.kind == .xml
        ? xmlNodeDump(buf, _doc._xmlDoc, _xmlNode, 0, 0)
        : htmlNodeDump(buf, _doc._xmlDoc, _xmlNode)
    if size == -1 { return nil }
    return _toStr(buf.pointee.content)
  }

  /// raw concont, node self excluded
  var innerRawContent: String? {
    childNodes?
      .map { $0.rawContent ?? "" }
      .joined(separator: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// attributes
  var attributes: AnySequence<Attribute>? {
    _xmlNode.pointee.properties.map { attr in
      AnySequence { () -> AnyIterator<Attribute> in
        var next: UnsafeMutablePointer<_xmlAttr>? = attr
        return AnyIterator {
          guard
            let nxt = next,
            let oriName = nxt.pointee.name.flatMap(self._toStr)
            else { return nil }
          next = nxt.pointee.next
          let nsPrefix = nxt.pointee.ns?.pointee.prefix.flatMap(self._toStr)
          let name = nsPrefix.map { "\($0):\(oriName)" } ?? oriName
          let value =
            nxt.pointee.ns == nil
              ? xmlGetProp(self._xmlNode, nxt.pointee.name)
              : xmlGetNsProp(self._xmlNode, nxt.pointee.name, nxt.pointee.ns!.pointee.href)
          return (name: name, value: value.flatMap(self._toStr))
        }
      }
    }
  }

  /// get attribute value for attribute name (ns prefix should be included if avaible)
  func value(forAttribute name: String) -> String? {
    let comps = name.split(separator: ":", maxSplits: 1)
    if comps.count == 1 { return xmlGetProp(_xmlNode, name).flatMap(_toStr) }
    let nsPrefix = String(comps[0])
    let propName = String(comps[1])
    var ns = _xmlNode.pointee.ns
    while ns != nil {
      if ns?.pointee.prefix.flatMap(_toStr) == nsPrefix, let href = ns?.pointee.href {
        return xmlGetNsProp(_xmlNode, propName, href).flatMap(_toStr)
      }
      ns = ns?.pointee.next
    }
    return nil
  }

  // MARK: - Hierarchy
  /// parent
  var parent: Node? {
    _xmlNode.pointee.parent.map { Node(_doc: _doc, _xmlNode: $0) }
  }

  /// childNodes
  var childNodes: AnySequence<Node>? {
    _xmlNode.pointee.children.map {
      var next: UnsafeMutablePointer<_xmlNode>? = $0
      return AnySequence<Node> { () -> AnyIterator<Node> in
        AnyIterator {
          guard let nxt = next else { return nil }
          let node = Node(_doc: self._doc, _xmlNode: nxt)
          next = nxt.pointee.next
          return node
        }
      }
    }
  }

  /// first child
  var firstNode: Node? {
    childNodes?.first { _ in true }
  }

  /// childNode at index
  func childNode(at index: Int) -> Node? {
    childNodes?.enumerated().first { (offset, _) in offset == index }?.element
  }

  /// previous sibling
  var prev: Node? {
    _xmlNode.pointee.prev.map { Node(_doc: _doc, _xmlNode: $0) }
  }

  /// next sibling
  var next: Node? {
    _xmlNode.pointee.next.map { Node(_doc: _doc, _xmlNode: $0) }
  }
}

// MARK: - XPath navigation
public extension Node {
  func select(xpath: String) -> [Node] {
    _select(xpath: xpath, firstOnly: false)
  }

  func first(xpath: String) -> Node? {
    _select(xpath: xpath, firstOnly: true).first
  }
}

// MARK: - XPath evaluation
public extension Node {
  func eval(expr: String) -> EvalResult? {
    guard let ctx = xmlXPathNewContext(_xmlNode.pointee.doc) else { return nil }
    defer { xmlXPathFreeContext(ctx) }
    ctx.pointee.node = _xmlNode
    _registerNs(ctx, _getPrefixesInXPath(expr))
    let norXpath = _doc._defaultNs.map { _normalize(xpath: expr, defaultNsPrefix: $0.0) } ?? expr
    guard let xpathObj = xmlXPathEval(norXpath, ctx) else { return nil }
    defer { xmlXPathFreeObject(xpathObj) }
    switch xpathObj.pointee.type {
    case XPATH_BOOLEAN:
      let val = xpathObj.pointee.boolval
      return .bool(val == 1)
    case XPATH_NUMBER:
      let val = xpathObj.pointee.floatval
      return .double(val)
    case XPATH_STRING:
      let val = xpathObj.pointee.stringval
      return val.flatMap(_toStrDontFreeArg).map { .string($0) }
    default:
      return nil
    }
  }
}

// MARK: - Privates
private extension Node {
  func _toStr(_ xc: UnsafeMutablePointer<xmlChar>!, _ needsFree: Bool) -> String? {
    defer { if needsFree { xmlFree(xc) } }
    return xc.flatMap {
      $0.withMemoryRebound(to: CChar.self, capacity: 0) {
        String(cString: $0, encoding: _doc.encoding)
      }
    }
  }

  func _toStr(_ xc: UnsafeMutablePointer<xmlChar>!) -> String? {
    _toStr(xc, true)
  }

  func _toStrDontFreeArg(_ xc: UnsafeMutablePointer<xmlChar>!) -> String? {
    _toStr(xc, false)
  }

  func _toStr(_ xc: UnsafePointer<xmlChar>!) -> String? {
    return xc.flatMap {
      $0.withMemoryRebound(to: CChar.self, capacity: 0) {
        String(cString: $0, encoding: _doc.encoding)
      }
    }
  }

  func _getPrefixesInXPath(_ xpath: String) -> Set<String> {
    guard
      let regexp = try? NSRegularExpression(pattern: "(\\w+):[^\\W:]", options: [])
      else { fatalError("Invalid regexp") }
    var set = Set<String>()
    regexp.enumerateMatches(in: xpath, options: [], range: NSRange(location: 0, length: xpath.utf16.count)) { (result, _flag, _stop) in
      guard let nr = result?.range(at: 1) else { return }
      let start = String.Index(utf16Offset: nr.location, in: xpath)
      let end = String.Index(utf16Offset: NSMaxRange(nr), in: xpath)
      set.insert(String(xpath[start..<end]))
    }
    return set
  }

  func _registerNs(_ ctx: xmlXPathContextPtr, _ prefixes: Set<String>) {
    var reged = Set<String>()
    var ns = _xmlNode.pointee.nsDef
    while ns != nil {
      let p = ns?.pointee.prefix
      let h = ns?.pointee.href
      if let prefix = p.flatMap(_toStr), !prefix.isEmpty {
        xmlXPathRegisterNs(ctx, prefix, h)
        reged.insert(prefix)
      } else if let href = h.flatMap(_toStr),
        !href.isEmpty,
        _doc._defaultNs == nil
      {
        let prx =
          href.split(separator: "/").last.flatMap(String.init)
            ?? href.data(using: .utf8)?.base64EncodedString()
            ?? href
        _doc._defaultNs = (prx, href)
        xmlXPathRegisterNs(ctx, prx, href)
        xmlNewNs(_doc._root, href, prx)
        reged.insert(prx)
      } else if let (dfNsPrx, href) = _doc._defaultNs {
        xmlXPathRegisterNs(ctx, dfNsPrx, href)
        reged.insert(dfNsPrx)
      }

      ns = ns?.pointee.next
    }
    if prefixes.isEmpty { return }
    let unreged = prefixes.subtracting(reged)
    for prefix in unreged {
      if let ns = xmlSearchNs(_doc._xmlDoc, _doc._root, prefix) {
        xmlXPathRegisterNs(ctx, ns.pointee.prefix, ns.pointee.href)
        continue
      }

      if let href = _doc._namespaces[prefix] {
        xmlXPathRegisterNs(ctx, prefix, href)
        continue
      }

      if
        let xpathObj = xmlXPathEval("string(//namespace::\(prefix))", ctx),
        let ns = xpathObj.pointee.stringval?.withMemoryRebound(to: Int8.self, capacity: 0, { $0 }),
        strlen(ns) > 0
      {
        xmlXPathRegisterNs(ctx, prefix, xpathObj.pointee.stringval)
        xmlNewNs(_doc._root, xpathObj.pointee.stringval, prefix)
        xmlXPathFreeObject(xpathObj)
        continue
      }

      fatalError("Can't find namespace URI for `\(prefix)`, you should register with doc.registerNamespace(prefix:uri:)")
    }
  }

  func _normalize(xpath: String, defaultNsPrefix: String) -> String {
    let template = "$1\(defaultNsPrefix):$2$3"
    let attrRegexp = try! NSRegularExpression(pattern: #"(?<!attribute)(\:\:)([a-z*][\w\d-_\.]*)([=\s\[\]]|$)"#, options: [])
    let pathRegexp = try! NSRegularExpression(pattern: #"(^|\()([a-z*][\w\d-_\.]*)([\)\[]|$)"#, options: [])
    let pathRegexp2 = try! NSRegularExpression(pattern: #"(\[)([a-z*][\w\d-_\.]*)([\]=])"#, options: [])
    return xpath
      .split(separator: "|", omittingEmptySubsequences: false)
      .map { path in
        path.split(separator: "/", omittingEmptySubsequences: false).map {
          let part = String($0)
          if part.isEmpty { return part }
          if path.contains("::") {
            let range = NSRange(location: 0, length: part.utf16.count)
            return attrRegexp.stringByReplacingMatches(in: part, options: [], range: range, withTemplate: template)
          }

          let r1 = NSRange(location: 0, length: part.utf16.count)
          let s1 = pathRegexp.stringByReplacingMatches(in: part, options: [], range: r1, withTemplate: template)
          let r2 = NSRange(location: 0, length: s1.utf16.count)
          return pathRegexp2.stringByReplacingMatches(in: s1, options: [], range: r2, withTemplate: template)
        }.joined(separator: "/")
      }.joined(separator: "|")
  }

  func _select(xpath: String, firstOnly: Bool) -> [Node] {
    guard let ctx = xmlXPathNewContext(_doc._xmlDoc) else { return [] }
    ctx.pointee.node = _xmlNode
    _registerNs(ctx, _getPrefixesInXPath(xpath))
    let norXpath = _doc._defaultNs.map { _normalize(xpath: xpath, defaultNsPrefix: $0.0) } ?? xpath
    guard let xpathObj = xmlXPathEval(norXpath, ctx) else { return [] }
    defer {
      xmlXPathFreeContext(ctx)
      xmlXPathFreeObject(xpathObj)
    }
    if xpathObj.pointee.type != XPATH_NODESET || xpathObj.pointee.nodesetval == nil { return [] }
    let numNodes = Int( xpathObj.pointee.nodesetval.pointee.nodeNr)
    if numNodes < 1 { return [] }
    let nodeset = xpathObj.pointee.nodesetval.pointee
    if nodeset.nodeTab.pointee?.pointee.type != XML_ELEMENT_NODE { return [] }
    return (0..<(firstOnly ? 1 : numNodes)).reduce(into: []) { (result, i) in
      let rawNode = nodeset.nodeTab.advanced(by: i)
      if let node = rawNode.pointee { result.append(Node(_doc: self._doc, _xmlNode: node)) }
    }
  }
}
