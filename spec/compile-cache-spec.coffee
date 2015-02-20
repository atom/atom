path = require 'path'
CSON = require 'season'
CoffeeCache = require 'coffee-cash'

babel = require '../src/babel'
CompileCache = require '../src/compile-cache'

describe "Compile Cache", ->
  describe ".addPathToCache(filePath)", ->
    it "adds the path to the correct CSON, CoffeeScript, or babel cache", ->
      spyOn(CSON, 'readFileSync').andCallThrough()
      spyOn(CoffeeCache, 'addPathToCache').andCallThrough()
      spyOn(babel, 'addPathToCache').andCallThrough()

      CompileCache.addPathToCache(path.join(__dirname, 'fixtures', 'cson.cson'))
      expect(CSON.readFileSync.callCount).toBe 1
      expect(CoffeeCache.addPathToCache.callCount).toBe 0
      expect(babel.addPathToCache.callCount).toBe 0

      CompileCache.addPathToCache(path.join(__dirname, 'fixtures', 'coffee.coffee'))
      expect(CSON.readFileSync.callCount).toBe 1
      expect(CoffeeCache.addPathToCache.callCount).toBe 1
      expect(babel.addPathToCache.callCount).toBe 0

      CompileCache.addPathToCache(path.join(__dirname, 'fixtures', 'babel', 'babel-double-quotes.js'))
      expect(CSON.readFileSync.callCount).toBe 1
      expect(CoffeeCache.addPathToCache.callCount).toBe 1
      expect(babel.addPathToCache.callCount).toBe 1
