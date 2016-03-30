//
//  SimpleXPathProtocols.swift
//  SimpleXPath
//
//  Created by CHEN Xian’an on 2/19/15.
//  Copyright (c) 2015 lazyapps. All rights reserved.
//

public enum XPathFunctionResult {
  case bool(Bool)
  case double(Double)
  case string(String)
}

protocol XPathLocating {
  
  func selectElements(withXPath: String) -> [XMLElement]
  
  func selectFirstElement(withXPath: String) -> XMLElement?
  
}

protocol XPathFunctionEvaluating {
  
  func evaluate(XPathFunction: String) -> XPathFunctionResult?
  
}
