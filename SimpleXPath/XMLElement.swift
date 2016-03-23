//
//  XMLElement.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 2/19/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

import libxml2

public typealias XMLAttribute = (name: String, value: String?)

public struct XMLElement {
  
  let _node: xmlNodePtr
  
}

public extension XMLElement {
  
  /// document type
  var documentType: XMLDocumentType {
    let root = xmlDocGetRootElement( _node.memory.doc)
    let name = xmlGetProp(root, _doctypeprop)
    return strcmp(unsafeBitCast(name, UnsafePointer<Int8>.self), "0") == 0 ? .XML : .HTML
  }
  
  /// Tag name
  var tag: String? {
    return _convertXmlCharPointerToString(_node.memory.name)
  }
  
  /// Content
  var content: String? {
    let c = xmlNodeGetContent(_node)
    if c == nil {
      return nil
    }
    
    let cstr = _convertXmlCharPointerToString(c)
    free(c)
    return cstr
  }
  
  /// Dump raw content, wrapper included
  var rawContent: String? {
    if (_node.memory.type == XML_TEXT_NODE) {
      return content
    }
    
    let buf = xmlBufferCreate()
    let size = documentType == .XML ? xmlNodeDump(buf, _node.memory.doc, _node, 0, 0) : htmlNodeDump(buf, _node.memory.doc, _node)
    if size == -1 { return nil }
    let cnt = _convertXmlCharPointerToString(buf.memory.content)
    xmlBufferFree(buf)
    return cnt
  }
  
  /// inner raw content, wrapper excluded
  var innerRawContent: String? {
    if let raws = (children?.map { $0.rawContent ?? "" }) {
      return raws.joinWithSeparator("").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
    
    return nil
  }
  
  /// Parent
  var parent: XMLElement? {
    let p = _node.memory.parent
    if p == nil {
      return nil
    }
    
    return XMLElement(_node: p)
  }
  
  /// Children
  var children: AnySequence<XMLElement>? {
    let c = _node.memory.children
    if c == nil {
      return nil
    }
    
    return AnySequence {
      _ -> AnyGenerator<XMLElement> in
      var n = c
      return AnyGenerator {
        if n == nil {
          return nil
        }
        
        let el = XMLElement(_node: n)
        n = n.memory.next
        return el
      }
    }
  }
  
  /// First child
  var firstChild: XMLElement? {
    if let childrenSeq = children {
      for el in childrenSeq {
        return el
      }
    }
    
    return nil
  }
  
  /// Get child at `index`,
  /// If `index` is overflow, return nil
  func childAtIndex(index: Int) -> XMLElement? {
    if let seq = children {
      for (i, el) in seq.enumerate() {
        if i == index {
          return el
        }
      }
    }
    
    return nil
  }
  
  /// Previous sibling
  var prev: XMLElement? {
    let p = _node.memory.prev
    if p == nil {
      return nil
    }
    
    return XMLElement(_node: p)
  }
  
  /// Next sibling
  var next: XMLElement? {
    let n = _node.memory.next
    if n == nil {
      return nil
    }
    
    return XMLElement(_node: n)
  }
  
  /// Attributes
  var attributes: AnySequence<XMLAttribute>? {
    let properties = _node.memory.properties
    if properties == nil {
      return nil
    }
    
    return AnySequence {
      _ -> AnyGenerator<XMLAttribute> in
      var p = properties
      return AnyGenerator {
        if p == nil {
          return nil
        }
        
        let cur = p
        p = p.memory.next
        let n = self._convertXmlCharPointerToString(cur.memory.name) ?? ""
        let v = xmlGetProp(self._node, cur.memory.name)
        let attr = XMLAttribute(n, self._convertXmlCharPointerToString(v))
        if v != nil { free(v) }
        return attr
      }
    }
  }
  
  /// Attribute value
  func valueForAttribute(attr: String, inNamespace nspace: String? = nil) -> String? {
    return _valueForAttribute(_node, attr.xmlCharPointer, nspace)
  }
  
  func unlink() {
    xmlUnlinkNode(_node)
  }
  
}

// MARK: implement XPathLocating
extension XMLElement: XPathLocating {
  
  public func selectElements(withXPath: String) -> AnySequence<XMLElement>? {
    let ctx = xmlXPathNewContext(_node.memory.doc)
    ctx.memory.node = _node
    _registerNS(ctx, xpath: withXPath)
    let xpathObj = xmlXPathEval(withXPath.xmlCharPointer, ctx)
    if xpathObj == nil ||
      xpathObj.memory.type.rawValue != XPATH_NODESET.rawValue ||
      xpathObj.memory.nodesetval == nil ||
      xpathObj.memory.nodesetval.memory.nodeNr == 0 {
        if xpathObj != nil { xmlXPathFreeObject(xpathObj) }
        return nil
    }
    
    let nodeset = xpathObj.memory.nodesetval.memory
    if nodeset.nodeTab.memory.memory.type.rawValue != XML_ELEMENT_NODE.rawValue { return nil }
    let seq = AnySequence {
      _ -> AnyGenerator<XMLElement> in
      let max = Int(nodeset.nodeNr) - 1
      var i = 0
      return AnyGenerator {
        if i > max {
          xmlXPathFreeContext(ctx)
          xmlXPathFreeObject(xpathObj)
          return nil
        }
        
        let node = nodeset.nodeTab.advancedBy(i)
        let el = XMLElement(_node: node.memory)
        i += 1
        return el
      }
    }
    
    return seq
  }
  
  public func selectFirstElement(withXPath: String) -> XMLElement? {
    if let els = selectElements(withXPath) {
      for el in els {
        return el
      }
    }
    
    return nil
  }
  
}

// MARK: implementing XPathFunctionEvaluating
extension XMLElement: XPathFunctionEvaluating {
  
  public func evaluate(function: String) -> XPathFunctionResult? {
    let ctx = xmlXPathNewContext(_node.memory.doc)
    ctx.memory.node = _node
    _registerNS(ctx, xpath: function)
    let xpathObj = xmlXPathEval(function.xmlCharPointer, ctx)
    if xpathObj == nil {
      return nil
    }
    
    let t = xpathObj.memory.type.rawValue
    let result: XPathFunctionResult?
    if t == XPATH_BOOLEAN.rawValue {
      let val = xpathObj.memory.boolval
      result = XPathFunctionResult.bool(val == 1 ? true : false)
    } else if t == XPATH_NUMBER.rawValue {
      let val = xpathObj.memory.floatval
      result = XPathFunctionResult.double(val)
    } else if t == XPATH_STRING.rawValue {
      let val = xpathObj.memory.stringval
      if let str = _convertXmlCharPointerToString(val) {
        result = XPathFunctionResult.string(str)
      } else {
        result = nil
      }
    } else {
      result = nil
    }
    
    xmlXPathFreeObject(xpathObj)
    return result
  }
  
}

// MARK: subscription
public extension XMLElement {
  
  subscript(attributeName: String) -> String? {
    return valueForAttribute(attributeName)
  }
  
}

// MARK: privates
private extension XMLElement {
  
  func _registerNS(ctx: xmlXPathContextPtr, xpath: String) {
    if let prefixsInsideXPath = xpath.namespacePrefixs {
      var registeredNS = Set<String>()
      var ns = _node.memory.nsDef;
      while (ns != nil) {
        if let prefix = _convertXmlCharPointerToString(ns.memory.prefix) {
          xmlXPathRegisterNs(ctx, ns.memory.prefix, ns.memory.href)
          registeredNS.insert(prefix)
        }
        
        ns = ns.memory.next
      }
      
      let unreg = prefixsInsideXPath.subtract(registeredNS)
      for prefix in unreg  {
        let root = xmlDocGetRootElement(_node.memory.doc)
        let ns = xmlSearchNs(_node.memory.doc, root, prefix.xmlCharPointer)
        if ns != nil {
          xmlXPathRegisterNs(ctx, ns.memory.prefix, ns.memory.href)
        } else {
          let xpathObj = xmlXPathEval("string(//namespace::\(prefix))", ctx)
          if xpathObj != nil && strlen(unsafeBitCast(xpathObj.memory.stringval, UnsafePointer<Int8>.self)) > 0 {
            xmlXPathRegisterNs(ctx, prefix.xmlCharPointer, xpathObj.memory.stringval)
            xmlNewNs(root, xpathObj.memory.stringval, prefix.xmlCharPointer)
          } else {
            fatalError("No chance to register namespace for `\(prefix)`, you can register it on XMLDocument by `registerDefaultNamespace(:, prefix:)`")
          }
          
          if xpathObj != nil { xmlXPathFreeObject(xpathObj) }
        }
      }
    }
  }
  
  func _valueForAttribute(node: xmlNodePtr, _ attr: UnsafePointer<xmlChar>, _ ns: String? = nil) -> String? {
    let val: UnsafeMutablePointer<xmlChar>
    if let n = ns {
      val = xmlGetNsProp(node, attr, n.xmlCharPointer)
    } else {
      val = xmlGetProp(node, attr)
    }

    if val == nil {
      return nil
    }
    
    let str = _convertXmlCharPointerToString(val)
    free(val)
    return str
  }
  
  func _convertXmlCharPointerToString(xmlCharP: UnsafePointer<xmlChar>) -> String? {
    if xmlCharP == nil {
      return nil
    }
    
    return String.fromCStringRepairingIllFormedUTF8(unsafeBitCast(xmlCharP, UnsafePointer<CChar>.self)).0
  }
  
}

