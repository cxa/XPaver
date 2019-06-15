# XPaver

Make XML navigation by XPath easier.

## Install

Swift package only. Add this repo url to your package dependencies. Xcode 11 supports by default.

## Usage

### Initialize a `Doc` first

```swift
  let xmlDoc = try! Doc(fileURL: assetURL(forName: "xml.xml"), kind: .xml)
  // or if you want to use on HTML
  let htmlDoc = try! Doc(fileURL: assetURL(forName: "html.html"), kind: .html)
```

### Navigate by XPath

```swift
// func select(xpath: String) -> [Node]
let nodes = htmlDoc.root.select(xpath: "//p") // Select all `p` on root node:

// func first(xpath: String) -> Node?
let p = htmlDoc.root.first(xpath: "//p")  // Select first `p` on root node:
let span = p.first("./span")                 // Select first child span on `p`
```

### Evaluate XPath Expression

```swift
func eval(expr: String) -> Node.EvalResult?

// count how many p tags
let count = htmlDoc.root.eval(expr: "count(//p)")
```

### Node Info

```swift
var tag: String?
var content: String?
var rawContent: String?
var innerRawContent: String?
var attributes: AnySequence<Node.Attribute>?
func value(forAttribute name: String) -> String?
```

### Node Hierarchies

```swift
var parent: Node?
var childNodes: AnySequence<Node>?
var firstNode: Node?
func childNode(at index: Int) -> Node?
var prev: Node?
var next: Node?
```

### Advanced usage on namespace

By default, `XPaver` will solve namespaces for you internally, you don't need to care namespaces if document has only one default namespace.

But if you encounter a XML which contains more than one namespace like this:

```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<person xmlns="http://www.your.example.com/xml/person">
  <name>Rob</name>
  <age>37</age>
  <homecity xmlns="http://www.my.example.com/xml/cities">
    <name>London</name>
    <lat>123.000</lat>
    <long>0.00</long>
  </homecity>
</person>
```

You need to register namespaces and write namespaces in XPath directly:

```swift
let mnsXmlDoc = try! Doc(fileURL: url, kind: .xml)
mnsXmlDoc.register(namespaceURI: "http://www.your.example.com/xml/person", forPrefix: "p")
mnsXmlDoc.register(namespaceURI: "http://www.my.example.com/xml/cities", forPrefix: "c")
let cityName = mnsXmlDoc.root.first(xpath: "/p:person/c:homecity/c:name")
```

## About Me

- Twitter: [@_cxa](https://twitter.com/_cxa)
- Apps available on the App Store: <http://lazyapps.com>
- PayPal: xianan.chen+paypal 📧 gmail.com, buy me a cup of coffee if you find this is useful for you

## LICENSE

MIT.