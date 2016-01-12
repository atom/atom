path = require('path')
temp = require('temp').track()
CompileCache = require('../src/compile-cache')

describe "Babel transpiler support", ->
  originalCacheDir = null

  beforeEach ->
    originalCacheDir = CompileCache.getCacheDirectory()
    CompileCache.setCacheDirectory(temp.mkdirSync('compile-cache'))
    for cacheKey in Object.keys(require.cache)
      if cacheKey.startsWith(path.join(__dirname, 'fixtures', 'babel'))
        console.log('deleting', cacheKey)
        delete require.cache[cacheKey]

  afterEach ->
    CompileCache.setCacheDirectory(originalCacheDir)

  describe 'when a .js file starts with /** @babel */;', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-comment.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file starts with 'use babel';", ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-single-quotes.js')
      expect(transpiled(3)).toBe 4

  describe 'when a .js file starts with "use babel";', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-double-quotes.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file does not start with 'use babel';", ->
    it "does not transpile it using babel", ->
      expect(-> require('./fixtures/babel/invalid.js')).toThrow()
