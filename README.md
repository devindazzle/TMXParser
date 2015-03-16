# TMXTiledMap is a TMX Map viewer for SpriteKit written in Swift

> TMXTiledMap will be available as soon as it has been tested well enough for being released to the public.


## How to use TMXTiledMap

Include the following files in your project:

	TMXTiledMap.swift
	TMXTilesetInfo.swift
	TMXLayer.swift

These files are stored in the TMXTiledMap folder.

## Limitations

The current version of TMXTiledMap has the following limitations:

* iOS 7 and later only (requires Swift that can only compile to iOS 7 and above)
* OS X not supported in current version
* External tilesets not supported in current version
* Terrain is not supported in current version

Some of these missing features will likely be added later but as I have no need for these features in my current projects I have no plan to eliminate these limitations in the near future.

## Special thanks

I would like to acknowledge the work of the following people who made it a whole lot simpler to make a TMX parser for Sprite Kit and Swift.

* **Steffen Itterheim** (KoboldKit, [https://github.com/KoboldKit]())
* **Jeremy Stone** (JSTileMap, [https://github.com/slycrel/JSTileMap]())
* **The Cocos2D community** (Cocos2D-SpriteBuilder, [https://github.com/cocos2d/cocos2d-spritebuilder]())