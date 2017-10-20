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
        static let FlipDiagonallyFlag: UInt32     = 0b00100000000000000000000000000000
        static let FlipVerticallyFlag: UInt32     = 0b01000000000000000000000000000000
        static let FlipHorizontallyFlag: UInt32   = 0b10000000000000000000000000000000
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
    
    /// Background color
    var backgroundColor: UIColor = UIColor.clear
    
    /// Map properties
    lazy var properties = [String : String]()
    
    /// An array of tile layers
    lazy var tileLayers = [TMXTileLayer]()
    
    /// An array of object groups
    lazy var objectGroups = [TMXObjectGroup]()
    
    /// An array of image layers
    lazy var imageLayers = [TMXImageLayer]()
    
    
    // MARK: Private properties for handling internal state
    
    fileprivate enum ParsingElementType: Int {
        case invalid, none, map, layer, data, objectGroup, object, polygon, polyline, property, animation, frame, imageLayer, image
        
        init(type: String) {
            switch type.lowercased() {
            case "data":
                self = .data
            case "layer":
                self = .layer
            case "map":
                self = .map
            case "object":
                self = .object
            case "objectgroup":
                self = .objectGroup
            case "polygon":
                self = .polygon
            case "polyline":
                self = .polyline
            case "property":
                self = .property
            case "animation":
                self = .animation
            case "frame":
                self = .frame
            case "imagelayer":
                self = .imageLayer
            case "image":
                self = .image
            default:
                self = .invalid
            }
        }
        
    }
    
    fileprivate var parsingElement: ParsingElementType = .none
    fileprivate var parsingData = false
    fileprivate var parsingDataString = ""
    
    
    init(filename name: NSString) {
        
        super.init()
        
        // sort out the filename for the map and get it's path
        let filename = name.deletingPathExtension
        var fileExtension = name.pathExtension
        
        // if the file contained no extension, then add the default "tmx" extension
        if fileExtension.isEmpty {
            fileExtension = "tmx"
        }
        
        guard let path = Bundle.main.path(forResource: filename, ofType: fileExtension) else {
            fatalError("Unable to load TMX file: \(name)")
        }
        
        do {
            
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: NSData.ReadingOptions.mappedIfSafe)
            
            // Parse the XML data
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.shouldProcessNamespaces = false
            parser.shouldReportNamespacePrefixes = false
            parser.shouldResolveExternalEntities = false
            
            if !parser.parse() {
                fatalError("Error parsing data, error: \(String(describing: parser.parserError))")
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        // Reset
        parsingElement = .none
        parsingData = false
        parsingDataString = ""
        
    }
    
    
    // MARK: Parse MAP element
    fileprivate func parseMapElement(_ attributeDict: [String : String]) {
        
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
        
        // Get the background color
        if let hexString = attributeDict["backgroundcolor"], hexString.hasPrefix("#") {
            let start = hexString.index(hexString.startIndex, offsetBy: 1)
            let hexColor = String(hexString[start...])
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                if hexColor.count == 8 {
                    let a = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    let r = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    let g = CGFloat((hexNumber & 0x0000ff00) >> 8 ) / 255
                    let b = CGFloat( hexNumber & 0x000000ff)        / 255
                    backgroundColor = UIColor(red: r, green: g, blue: b, alpha: a)
                } else if hexColor.count == 6 {
                    let r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    let g = CGFloat((hexNumber & 0x00ff00) >> 8)  / 255
                    let b = CGFloat( hexNumber & 0x0000ff)        / 255
                    backgroundColor = UIColor(red: r, green: g, blue: b, alpha: 1)
                }
            }
        }
        
    }
    
    // MARK: Parse LAYER element
    fileprivate func parseLayerElement(_ attributeDict: [String : String]) {
        
        // Create a new tile layer
        let layer = TMXTileLayer(parser: self)
        
        // Name of layer
        if let name = attributeDict["name"] {
            layer.name = name
        }
        
        // Visibility of layer
        if let visible = attributeDict["visible"] {
            layer.visible = visible != "0"
        }
        
        // Add the tile layer to the tileLayers array
        tileLayers.append(layer)
        
    }
    
    
    // MARK: Parse DATA element
    fileprivate func parseDataElement(_ attributeDict: [String : String]) {
        if let encoding = attributeDict["encoding"] {
            if encoding != "csv" {
                fatalError("Please make sure the TMX file has CSV encoding for map data")
            }
            parsingData = true
        }
    }
    
    
    // MARK: Parse CSV encoded string
    fileprivate func parseCSVEncodedTileDataString() {
        
        // Parse CSV data
        let gIDArray = parsingDataString.components(separatedBy: ",")
        
        // Check if the number of gIDs in gIDArray
        assert(gIDArray.count == (width * height), "Error parsing tile data: \(Int(width) * Int(height)) tiles were expected but tile data contains \(gIDArray.count) tiles.")
        
        // Get the tile layer that contains these tiles
        guard let layer = tileLayers.last else {
            fatalError("Error parsing tile data. There are no tile layers to associate the tile data with!")
        }
        
        // Copy the data into the layer
        for i in 0..<gIDArray.count {
            
            // Get the gID of the tile - including flip flags
            guard var gID = UInt32(gIDArray[i].replacingOccurrences(of: "\n", with: "")) else {
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
    fileprivate func parseObjectGroup(_ attributeDict: [String : String]) {
        
        // Create a new object group
        let group = TMXObjectGroup(parser: self)
        
        // Name of object group
        if let name = attributeDict["name"] {
            group.name = name
        }
        
        // Visibility of object group
        if let visible = attributeDict["visible"] {
            group.visible = visible != "0"
        }
        
        // Add the object group to the objectGroups array
        objectGroups.append(group)
        
    }
    
    // MARK: Parse OBJECT element
    fileprivate func parseObject(_ attributeDict: [String : String]) {
        
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
        if let width = attributeDict["width"], let height = attributeDict["height"] {
            object.size = CGSize(width: Int(width)!, height: Int(height)!)
        }
        
        // The position of the object - the y-coordinate is reversed as OpenGL ES has origin in bottom left corner (and not top left as Tiled uses)
        if let x = attributeDict["x"], let y = attributeDict["y"] {
            object.position = CGPoint(
                x: CGFloat(Int(x)!),
                y: size.height - CGFloat(Int(y)!)
            )
            object.position.y -= object.size.height
        }
        
        // A reference to a tile gID
        if let gID = attributeDict["gid"] {
            object.gID = Int(gID)!
            object.objectType = .tile
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
    fileprivate func parsePolylineElement(_ attributeDict: [String : String]) {
        if let pointsString = attributeDict["points"], let points = pointsFromPointString(pointsString), let path = pathFromPoints(points, closePath: true) {
            if let object = parsingObject() {
                object.objectType = .polyLine
                object.points = points
                object.path = path
            }
        }
    }
    
    // MARK: Parse POLYGON element
    fileprivate func parsePolygonElement(_ attributeDict: [String : String]) {
        if let pointsString = attributeDict["points"], let points = pointsFromPointString(pointsString), let path = pathFromPoints(points, closePath: false) {
            if let object = parsingObject() {
                object.objectType = .polygon
                object.points = points
                object.path = path
            }
        }
    }
    
    // MARK: Parse PROPERTY element
    fileprivate func parsePropertyElement(_ attributeDict: [String : String]) {
        
        if let key = attributeDict["name"], let value = attributeDict["value"] {
            
            switch parsingElement {
            case .map:
                // Add property to map
                properties[key] = value
                
            case .layer:
                // Add property to tile layer
                guard let layer = tileLayers.last else {
                    fatalError("Error parsing property data. There are no tile layers to associate the property with!")
                }
                layer.properties[key] = value
                
            case .objectGroup:
                // Add property to object group
                guard let group = objectGroups.last else {
                    fatalError("Error parsing object group property. There are no object groups to associate the property with!")
                }
                group.properties[key] = value
                
            case .object:
                // Add property to object
                guard let object = parsingObject() else {
                    fatalError("Error parsing object property. There are no objects to associate the property with!")
                }
                object.properties[key] = value
                
            case .imageLayer:
                // Add property to image layer
                guard let layer = imageLayers.last else {
                    fatalError("Error parsing image layer property. There are no image layers to associate the property with!")
                }
                layer.properties[key] = value
                
            default:
                print("Parsing of property for element not yet implememted.")
            }
            
        }
        
    }
    
    
    // MARK: Parse ImageLayer element
    fileprivate func parseImageLayerElement(_ attributeDict: [String : String]) {
        
        // Create a new object group
        let layer = TMXImageLayer(parser: self)
        
        // Name of image layer
        if let name = attributeDict["name"] {
            layer.name = name
        }
        
        // Visibility of image layer
        if let visible = attributeDict["visible"] {
            layer.visible = visible != "0"
        }
        
        // The horizontal offset of the image layer
        if let offsetX = attributeDict["offsetx"] {
            layer.offsetX = CGFloat(Int(offsetX)!)
        }
        
        // The vertical offset of the image layer
        if let offsetY = attributeDict["offsety"] {
            layer.offsetY = CGFloat(Int(offsetY)!)
        }
        
        // The opacity of the image layer
        if let opacity = attributeDict["opacity"] {
            layer.opacity = CGFloat(Double(opacity)!)
        }
        
        // Add the object group to the objectGroups array
        imageLayers.append(layer)
        
    }
    
    
    // MARK: Parse Image element
    fileprivate func parseImageElement(_ attributeDict: [String : String]) {
        
        let image = TMXImage()
        
        // The source of the image
        if let source = attributeDict["source"] {
            image.source = source
        }
        
        // The width of the image
        if let width = attributeDict["width"] {
            image.width = CGFloat(Int(width)!)
        }
        
        // The height of the image
        if let height = attributeDict["height"] {
            image.height = CGFloat(Int(height)!)
        }
        
        // Assign image to the object being parsed
        switch parsingElement {
        case .imageLayer:
            // Add image to image layer element
            guard let layer = imageLayers.last else {
                fatalError("Error parsing image data. There are no image layers to associate the image with!")
            }
            
            layer.image = image
            
        default:
            print("Parsing of image for element not yet implememted.")
        }
        
    }
    
    
    // MARK: Helper functions
    
    /// Gets the object that is currently being parsed
    fileprivate func parsingObject() -> TMXObject? {
        return objectGroups.last?.objects.last
    }
    
    /// Creates an array of CGPoints from a string containing points
    fileprivate func pointsFromPointString(_ pointString: String) -> [CGPoint]? {
        
        // Split the pointsString into individual points
        let pointStrings = pointString.components(separatedBy: " ")
        
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
    fileprivate func pathFromPoints(_ points: [CGPoint], closePath: Bool) -> CGPath? {
        
        // Convert points into a CGPath
        let path = CGMutablePath()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        if closePath {
            // Close the path (polygons)
            path.addLine(to: points[0])
        }
        
        return path
        
    }
    
    
    // MARK: Description
    override var description: String {
        return "Map size in tiles: {\(width), \(height)} - tile size: {\(tileWidth), \(tileHeight)}, size: \(size), # tile layers: \(tileLayers.count), #object groups: \(objectGroups.count)"
    }
    
}


// MARK: - NSXMLParserDelegate

extension TMXParser: XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        // Get the type of element to parse
        switch ParsingElementType(type: elementName) {
        case .object:
            parseObject(attributeDict)
            parsingElement = .object
            
        case .objectGroup:
            parseObjectGroup(attributeDict)
            parsingElement = .objectGroup
            
        case .polygon:
            parsePolygonElement(attributeDict)
            
        case .polyline:
            parsePolylineElement(attributeDict)
            
        case .layer:
            parseLayerElement(attributeDict)
            parsingElement = .layer
            
        case .imageLayer:
            parseImageLayerElement(attributeDict)
            parsingElement = .imageLayer
            
        case .image:
            parseImageElement(attributeDict)
            
        case .data:
            parseDataElement(attributeDict)
            
        case .frame:
            break
            
        case .animation:
            break
            
        case .property:
            parsePropertyElement(attributeDict)
            
        case .map:
            parseMapElement(attributeDict)
            parsingElement = .map
            
        default:
            break
        }
        
    }
    
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        switch ParsingElementType(type: elementName) {
        case .data:
            if parsingData {
                parseCSVEncodedTileDataString()
            }
            
        case .layer, .map, .object, .objectGroup, .imageLayer:
            parsingElement = .none
            
        default:
            break
        }
        
    }
    
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if parsingData {
            parsingDataString += string
        }
    }
    
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError("An error occured while parsing data: \(parseError.localizedDescription)")
    }
    
}


// MARK: - TMXTileLayer

class TMXTileLayer {
    
    /// A reference to the TMXParser this layer belongs to
    unowned let parser: TMXParser
    
    /// The name of the layer
    var name = ""
    
    /// The visibility of the layer
    var visible = true
    
    /// A 2D array of tiles
    fileprivate(set) var tiles: Array2D<TMXTile>
    
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
    var rect = CGRect.zero
    
    /// The position for this tile
    var position = CGPoint.zero
    
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
    
    /// The visibility of the object group
    var visible = true
    
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
    case unset, rectangle, polygon, polyLine, ellipse, tile
}



class TMXObject {
    
    /// A reference to the object group this object belongs to
    unowned let group: TMXObjectGroup
    
    /// Unique ID of the object. Each object that is placed on a map gets a unique id. Even if an object was deleted, no object gets the same ID.
    var id = -1
    
    /// The type of object - this is the internal type - not to be confused with the 'type' property
    var objectType: TMXObjectType = .unset
    
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
    var path: CGPath?
    
    /// Object properties
    lazy var properties = [String : String]()
    
    /// Initializer
    init(group: TMXObjectGroup) {
        self.group = group
    }
    
}



// MARK: - TMXImageLayer
class TMXImageLayer {
    
    /// A reference to the TMXParser this object group belongs to
    unowned let parser: TMXParser
    
    /// The name of the layer
    var name = ""
    
    /// The visibility of the layer
    var visible = true
    
    /// The horizontal offset of the layer
    var offsetX: CGFloat = 0
    
    /// The vertical offset of the layer
    var offsetY: CGFloat = 0
    
    /// The opacity of the layer
    var opacity: CGFloat = 1
    
    /// The image for this layer
    var image: TMXImage?
    
    /// Image layer properties
    lazy var properties = [String : String]()
    
    /// Initializer
    init(parser: TMXParser) {
        // Set a reference to the parser
        self.parser = parser
    }
    
}



// MARK: - TMXImage
class TMXImage {
    
    /// The source of the image
    var source: String = ""
    
    /// The width of the image
    var width: CGFloat = 0
    
    /// The height of the image
    var height: CGFloat = 0
    
}
