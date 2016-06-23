# TMXParser is a TMX parser written in Swift. It supports Swift 2.0 and up.

TMXParser will parse TMX files created with [Tiled Map Editor](http://www.mapeditor.org/) so that you will be able to easily create the tiles and objects for your game. 

TMXParser will not create nodes or other SpriteKit objects. This is done intentionally as the implementation of this is likely to depend on the game you are creating. Instead, the tile map information will be stored conviniently for you to create the tiles and objects in code.

## How to use TMXParser

Include the following files in your project:

	Array2D.swift
	TMXParser.swift

Then create an instance of TMXParser:

	let parser = TMXParser(filename: "level.tmx")

Also, create a Texture Atlas with each individual tile named by the gID given by Tiled (at least, that is how I prefer to do it - but it is up to you). A gID = 0 will be an empty tile - in the below example, a tile with gID = 0 will not be used. That means your first tile should have the name 1.png.

## Create tile layers

If you want to create the tiles for a map, it can be done like so:
	
	// Load a texture atlas
	let atlas = SKTextureAtlas(named: "textures.atlas")
	
	// Parse tile layers
    	for layer in parser.tileLayers {
    		for row in 0..<layer.tiles.rows {
        		for column in 0..<layer.tiles.columns {
          			
          			// Get the tile information
          			guard let tile = layer.tiles[column, row] where tile.gID > 0 else {
            				continue
          			}
          			
          			// Create a sprite node for the tile
          			let tileNode = SKSpriteNode(texture: atlas.textureNamed("\(tile.gID)"))
          			tileNode.position = tile.position
          			tileNode.zPosition = CGFloat(row)
          			tileNode.xScale = tile.flippedHorizontally ? -1.0 : 1.0
          			tileNode.yScale = tile.flippedVertically ? -1.0 : 1.0
          
          			// Add the tileNode to the chunk node
          			node.addChild(tileNode)
        		}
		}
    	}
    	
Simple as that - although for larger tile maps, I suggest you do not create all tiles at once. Again, it is totally up to you :)

## Limitations

The current version of TMXParser has the following limitations:

* iOS 7 and later only (requires Swift that can only compile to iOS 7 and above)
* OS X not supported in current version
* Only orthogonal maps in CSV format supported
* External tilesets not supported in current version
* Terrain is not supported in current version
* Image layers not supported
* Some properties for different objects do not exist. Easy to add.

Some of these missing features will likely be added later but as I have no need for these features in my current projects I have no plan to eliminate these limitations in the near future.

## Special thanks

I would like to acknowledge the work of the following people who made it a whole lot simpler to make a TMX parser for Sprite Kit and Swift.

* **Thorbjørn Lindeijer** (Tiled Map Editor, [http://www.mapeditor.org/](http://www.mapeditor.org/))
* **Steffen Itterheim** (KoboldKit, [https://github.com/KoboldKit](https://github.com/KoboldKit))
* **Jeremy Stone** (JSTileMap, [https://github.com/slycrel/JSTileMap](https://github.com/slycrel/JSTileMap))
* **The Cocos2D community** (Cocos2D-SpriteBuilder, [https://github.com/cocos2d/cocos2d-spritebuilder](https://github.com/cocos2d/cocos2d-spritebuilder))
