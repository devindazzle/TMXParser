import UIKit

//
//  Created by Kim Pedersen on 27/10/2015.
//  Copyright © 2015 twoFly. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products
//    derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

class TMXParser: NSObject {
  
  // MARK: TileFlipped flag enum
  private struct TMXTileFlags {
    static let FlipDiagonallyFlag: UInt32     = 0b00100000000000000000000000000000  // 0x20000000  // 00100000000000000000000000000000
    static let FlipVerticallyFlag: UInt32     = 0b01000000000000000000000000000000  // 0x40000000  // 01000000000000000000000000000000
    static let FlipHorizontallyFlag: UInt32   = 0b10000000000000000000000000000000  // 0x80000000  // 10000000000000000000000000000000
    static let FlipAll: UInt32                = FlipHorizontallyFlag | FlipVerticallyFlag | FlipDiagonallyFlag
    static let FlipMask: UInt32               = ~FlipAll
  }
  
  // MARK: Properties
  
  /// The map width in tiles
  var width: Int = 0
  
  /// The map height in tiles
  var height: Int = 0
  
  /// The width of a tile in points
  var tileWidth: Int = 0
  
  /// The height of a tile in points
  var tileHeight: Int = 0
  
  /// The size of a tile (calculated)
  var tileSize: CGSize {
    return CGSize(width: tileWidth, height: tileHeight)
  }
  
  /// The size of the map in points - calculated
  var size: CGSize {
    return CGSize(width: width * tileWidth, height: height * tileHeight)
  }
  
  /// Map properties
  lazy var properties = [String : String]()
  
  /// An array of tile layers
  lazy var tileLayers = [TMXTileLayer]()
  
  /// An array of object groups
  lazy var objectGroups = [TMXObjectGroup]()
  
  
  // MARK: Private properties for handling internal state
  
  private enum ParsingElementType: Int {
    case Invalid, None, Map, Layer, Data, ObjectGroup, Object, Polygon, Polyline, Property
    
    init(type: String) {
      switch type.lowercaseString {
      case "data":
        self = .Data
      case "layer":
        self = .Layer
      case "map":
        self = .Map
      case "object":
        self = .Object
      case "objectgroup":
        self = .ObjectGroup
      case "polygon":
        self = .Polygon
      case "polyline":
        self = .Polyline
      case "property":
        self = .Property
      default:
        self = .Invalid
      }
    }
    
  }
  
  private var parsingElement: ParsingElementType = .None
  private var parsingData = false
  private var parsingDataString = ""
  
  
  init(filename name: NSString) {
    
    super.init()
    
    // sort out the filename for the map and get it's path
    let filename = name.stringByDeletingPathExtension
    var fileExtension = name.pathExtension
    
    // if the file contained no extension, then add the default "tmx" extension
    if fileExtension.isEmpty {
      fileExtension = "tmx"
    }
    
    guard let path = NSBundle.mainBundle().pathForResource(filename, ofType: fileExtension) else {
      fatalError("Unable to load TMX file: \(name)")
    }
    
    do {
      
      let data = try NSData(contentsOfFile: path, options: NSDataReadingOptions.DataReadingMappedIfSafe)
      
      // Parse the XML data
      let parser = NSXMLParser(data: data)
      parser.delegate = self
      parser.shouldProcessNamespaces = false
      parser.shouldReportNamespacePrefixes = false
      parser.shouldResolveExternalEntities = false
      
      if !parser.parse() {
        fatalError("Error parsing data, error: \(parser.parserError)")
      }
      
    } catch let error as NSError {
      print(error.localizedDescription)
    }
    
    // Reset
    parsingElement = .None
    parsingData = false
    parsingDataString = ""
    
  }
  
  
  // MARK: Parse MAP element
  private func parseMapElement(attributeDict: [String : String]) {
    
    // Get the size of the map in tiles
    
    if let width = attributeDict["width"] {
       self.width = Int(width)!
    }
    
    if let height = attributeDict["height"] {
      self.height = Int(height)!
    }
    
    // Get the size of the tiles in the map (in points)
    
    if let tileWidth = attributeDict["tilewidth"] {
      self.tileWidth = Int(tileWidth)!
    }
    
    if let tileHeight = attributeDict["tileheight"] {
      self.tileHeight = Int(tileHeight)!
    }
    
  }
  
  // MARK: Parse LAYER element
  private func parseLayerElement(attributeDict: [String : String]) {
    
    // Create a new tile layer
    let layer = TMXTileLayer(parser: self)
    
    // Name of layer
    if let name = attributeDict["name"] {
      layer.name = name
    }
    
    // Add the tile layer to the tileLayers array
    tileLayers.append(layer)
    
  }
  
  
  // MARK: Parse DATA element
  private func parseDataElement(attributeDict: [String : String]) {
    if let encoding = attributeDict["encoding"] {
      if encoding != "csv" {
        fatalError("Please make sure the TMX file has CSV encoding for map data")
      }
      parsingData = true
    }
  }
  
  
  // MARK: Parse CSV encoded string
  private func parseCSVEncodedTileDataString() {
    
    // Parse CSV data
    let gIDArray = parsingDataString.componentsSeparatedByString(",")
    
    // Check if the number of gIDs in gIDArray
    assert(gIDArray.count == (width * height), "Error parsing tile data: \(Int(width) * Int(height)) tiles were expected but tile data contains \(gIDArray.count) tiles.")
    
    // Get the tile layer that contains these tiles
    guard let layer = tileLayers.last else {
      fatalError("Error parsing tile data. There are no tile layers to associate the tile data with!")
    }
    
    // Copy the data into the layer
    for i in 0..<gIDArray.count {
      
      // Get the gID of the tile - including flip flags
      guard var gID = UInt32(gIDArray[i].stringByReplacingOccurrencesOfString("\n", withString: "")) else {
        fatalError("Invalid gID detected!")
      }
      
      // Get flip flags from gID
      let flags = gID & TMXTileFlags.FlipAll
      
      // Remove the flip flags from the gID
      gID &= TMXTileFlags.FlipMask
      
      // Calculate the position of the tile
      let col = i % width
      let row = i / width
      
      // Calculate the tile rect
      let rect = CGRect(
        x: col * tileWidth,
        y: Int(size.height) - (row + 1) * tileHeight,
        width: tileWidth,
        height: tileHeight
      )
      
      // Create a tile
      let tile = TMXTile(layer: layer)
      
      tile.gID = Int(gID)
      tile.column = col
      tile.row = row
      tile.position = rect.center()
      tile.rect = rect
      
      // Tile flipping
      tile.flippedHorizontally = flags & TMXTileFlags.FlipHorizontallyFlag != 0
      tile.flippedVertically   = flags & TMXTileFlags.FlipVerticallyFlag != 0
      tile.flippedDiagonally   = flags & TMXTileFlags.FlipDiagonallyFlag != 0
      
      // Add the tile to the layer
      layer.tiles[col, row] = tile
      
    }
    
    // Reset state
    parsingData = false
    parsingDataString = ""
    
  }
  
  // MARK: Parse OBJECTGROUP element
  private func parseObjectGroup(attributeDict: [String : String]) {
    
    // Create a new object group
    let group = TMXObjectGroup(parser: self)
    
    // Name of object group
    if let name = attributeDict["name"] {
      group.name = name
    }
    
    // Add the object group to the objectGroups array
    objectGroups.append(group)
    
  }
  
  // MARK: Parse OBJECT element
  private func parseObject(attributeDict: [String : String]) {
    
    // Get the object group that contains this object
    guard let group = objectGroups.last else {
      fatalError("Error parsing object data. There are no object groups to associate the object with!")
    }
    
    // Create a new object
    let object = TMXObject(group: group)
    
    // Unique object ID
    if let id = attributeDict["id"] {
      object.id = Int(id)!
    }
    
    // Name of object
    if let name = attributeDict["name"] {
      object.name = name
    }
    
    // Type of object
    if let type = attributeDict["type"] {
      object.type = type
    }
    
    // The size of the object
    if let width = attributeDict["width"], height = attributeDict["height"] {
      object.size = CGSize(width: Int(width)!, height: Int(height)!)
    }
    
    // The position of the object - the y-coordinate is reversed as OpenGL ES has origin in bottom left corner (and not top left as Tiled uses)
    if let x = attributeDict["x"], y = attributeDict["y"] {
      object.position = CGPoint(
        x: CGFloat(Int(x)!) + object.size.width * 0.5,
        y: size.height - (CGFloat(Int(y)!) + object.size.height * 0.5)
      )
    }
    
    // A reference to a tile gID
    if let gID = attributeDict["gid"] {
      object.gID = Int(gID)!
      object.size = CGSize(width: tileWidth, height: tileHeight)
      object.position.y += CGFloat(tileHeight) // TODO: FIX HACK!!!
      object.objectType = .Tile
    }
    
    // The rotation of the object
    if let rotation = attributeDict["rotation"] {
      print("Remember to implement converting \(rotation) degrees to radians for object..")
    }
    
    // The visibility
    if let visible = attributeDict["visible"] {
      if visible == "0" {
        object.visible = false
      }
    }
    
    // Add the object to the object group
    group.objects.append(object)
    
  }
  
  // MARK: Parse POLYLINE element
  private func parsePolylineElement(attributeDict: [String : String]) {
    if let pointsString = attributeDict["points"], points = pointsFromPointString(pointsString), path = pathFromPoints(points, closePath: true) {
      if let object = parsingObject() {
        object.objectType = .PolyLine
        object.points = points
        object.path = path
      }
    }
  }
  
  // MARK: Parse POLYGON element
  private func parsePolygonElement(attributeDict: [String : String]) {
    if let pointsString = attributeDict["points"], points = pointsFromPointString(pointsString), path = pathFromPoints(points, closePath: false) {
      if let object = parsingObject() {
        object.objectType = .Polygon
        object.points = points
        object.path = path
      }
    }
  }
  
  // MARK: Parse PROPERTY element
  private func parsePropertyElement(attributeDict: [String : String]) {
    
    if let key = attributeDict["name"], value = attributeDict["value"] {
      
      switch parsingElement {
      case .Map:
        // Add property to map
        properties[key] = value
        
      case .Layer:
        // Add property to tile layer
        guard let layer = tileLayers.last else {
          fatalError("Error parsing property data. There are no tile layers to associate the property with!")
        }
        layer.properties[key] = value
        
      case .ObjectGroup:
        // Add property to object group
        guard let group = objectGroups.last else {
          fatalError("Error parsing object group property. There are no object groups to associate the property with!")
        }
        group.properties[key] = value
        
      case .Object:
        // Add property to object
        guard let object = parsingObject() else {
          fatalError("Error parsing object property. There are no objects to associate the property with!")
        }
        object.properties[key] = value
        
      default:
        print("Parsing of property for element not yet implememted.")
        
        break
      }
      
    }
    
  }
  
  
  // MARK: Helper functions
  
  /// Gets the object that is currently being parsed
  private func parsingObject() -> TMXObject? {
    return objectGroups.last?.objects.last
  }
  
  /// Creates an array of CGPoints from a string containing points
  private func pointsFromPointString(pointString: String) -> [CGPoint]? {
    
    // Split the pointsString into individual points
    let pointStrings = pointString.componentsSeparatedByString(" ")
    
    // If there are no points, then return nil
    if pointStrings.count < 1 {
      return nil
    }
    
    // Convert each point string into a CGPoint
    var points = [CGPoint]()
    
    for pt in pointStrings {
      var point = CGPointFromString("{\(pt)}")
      point.y *= -1
      points.append(point)
    }
    
    return points
    
  }
  
  
  /// Creates a CGPath from an array of points
  private func pathFromPoints(points: [CGPoint], closePath: Bool) -> CGPath? {
    
    // Convert points into a CGPath
    let path = CGPathCreateMutable()
    CGPathMoveToPoint(path, nil, points[0].x, points[0].y)
    for i in 1..<points.count {
      CGPathAddLineToPoint(path, nil, points[i].x, points[i].y)
    }
    
    if closePath {
      // Close the path (polygons)
      CGPathAddLineToPoint(path, nil, points[0].x, points[0].y)
    }
    
    return path
    
  }
  
  
  // MARK: Description
  override var description: String {
    return "Map size in tiles: {\(width), \(height)} - tile size: {\(tileWidth), \(tileHeight)}, size: \(size), # tile layers: \(tileLayers.count), #object groups: \(objectGroups.count)"
  }
  
}


// MARK: - NSXMLParserDelegate

extension TMXParser: NSXMLParserDelegate {
  
  func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
    
    // Get the type of element to parse
    switch ParsingElementType(type: elementName) {
    case .Object:
      parseObject(attributeDict)
      parsingElement = .Object
    
    case .ObjectGroup:
      parseObjectGroup(attributeDict)
      parsingElement = .ObjectGroup
      
    case .Polygon:
      parsePolygonElement(attributeDict)
    
    case .Polyline:
      parsePolylineElement(attributeDict)
    
    case .Layer:
      parseLayerElement(attributeDict)
      parsingElement = .Layer
    
    case .Data:
      parseDataElement(attributeDict)
      
    case .Property:
      parsePropertyElement(attributeDict)
      
    case .Map:
      parseMapElement(attributeDict)
      parsingElement = .Map
      
    default:
      break
    }
    
  }
  
  
  func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
    switch ParsingElementType(type: elementName) {
    case .Data:
      if parsingData {
        parseCSVEncodedTileDataString()
      }
      
    case .Layer, .Map, .Object, .ObjectGroup:
      parsingElement = .None
      
    default:
      break
    }
    
  }
  
  
  func parser(parser: NSXMLParser, foundCharacters string: String) {
    if parsingData {
      parsingDataString += string
    }
  }
  
  
  func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
    fatalError("An error occured while parsing data: \(parseError.localizedDescription)")
  }
  
}


// MARK: - TMXTileLayer

class TMXTileLayer {
  
  /// A reference to the TMXParser this layer belongs to
  unowned let parser: TMXParser
  
  /// The name of the layer
  var name = ""
  
  /// A 2D array of tiles
  private(set) var tiles: Array2D<TMXTile>
  
  /// Layer properties
  lazy var properties = [String : String]()
  
  /// Initializer
  init(parser: TMXParser) {
    
    // Set a reference to the parser
    self.parser = parser
    
    // Create the tiles array
    tiles = Array2D<TMXTile>(columns: parser.width, rows: parser.height)
  }
  
  
}


// MARK: - TMXTile

class TMXTile {
  
  /// A reference to the TMXLayer this tile belongs to
  unowned let layer: TMXTileLayer
  
  /// A global tile ID
  var gID: Int = 0
  
  /// The column this tile occupies
  var column: Int = 0
  
  /// The row this tile occupies
  var row: Int = 0
  
  /// The rectangle for this tile
  var rect = CGRectZero
  
  /// The position for this tile
  var position = CGPointZero
  
  /// Is this tile flipped horizontally
  var flippedHorizontally = false
  
  /// Is this tile flipped vertically
  var flippedVertically = false
  
  /// Is this tile flipped diagonally
  var flippedDiagonally = false
  
  /// Initializer
  init(layer: TMXTileLayer) {
    
    // Set a reference to the tile layer
    self.layer = layer
    
  }
  
}


// MARK: - TMXObjectGroup

class TMXObjectGroup {
  
  /// A reference to the TMXParser this object group belongs to
  unowned let parser: TMXParser
  
  /// The name of the layer
  var name = ""
  
  /// An array of objects belonging to this object group
  lazy var objects = [TMXObject]()
  
  /// Object group properties
  lazy var properties = [String : String]()
  
  /// Initializer
  init(parser: TMXParser) {
    // Set a reference to the parser
    self.parser = parser
  }
  
}


// MARK: - TMXObject
enum TMXObjectType: Int {
  case Unset, Rectangle, Polygon, PolyLine, Ellipse, Tile
}



class TMXObject {
  
  /// A reference to the object group this object belongs to
  unowned let group: TMXObjectGroup
  
  /// Unique ID of the object. Each object that is placed on a map gets a unique id. Even if an object was deleted, no object gets the same ID.
  var id = -1
  
  /// The type of object - this is the internal type - not to be confused with the 'type' property
  var objectType: TMXObjectType = .Unset
  
  /// A reference to a tile (optional).
  var gID = -1
  
  /// The type of the object. An arbitrary string.
  var type = ""
  
  /// The name of the object. An arbitrary string.
  var name = ""
  
  /// The position of the object
  var position = CGPoint.zero
  
  /// The size of the object (defaults to 0, 0)
  var size = CGSize.zero
  
  /// The rotation of the object in degrees clockwise (defaults to 0)
  var rotation: CGFloat = 0
  
  /// The visibility of the object
  var visible: Bool = true
  
  /// An array of points (only relevant if either a polyline or polygon object)
  var points: [CGPoint]?
  
  /// A path (only relevant if either a polyline or polygon object)
  var path: CGPathRef?
  
  /// Object properties
  lazy var properties = [String : String]()
  
  /// Initializer
  init(group: TMXObjectGroup) {
    self.group = group
  }
  
}
