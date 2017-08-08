# Users may have this environment variable set. Currently, it causes babel to
# log to stderr, which causes errors on Windows.
# See https://github.com/atom/electron/issues/2033
process.env.DEBUG='*'

path = require 'path'
temp = require('temp').track()
CompileCache = require '../src/compile-cache'

describe "Babel transpiler support", ->
  originalCacheDir = null

  beforeEach ->
    originalCacheDir = CompileCache.getCacheDirectory()
    CompileCache.setCacheDirectory(temp.mkdirSync('compile-cache'))
    for cacheKey in Object.keys(require.cache)
      if cacheKey.startsWith(path.join(__dirname, 'fixtures', 'babel'))
        delete require.cache[cacheKey]

  afterEach ->
    CompileCache.setCacheDirectory(originalCacheDir)
    try
      temp.cleanupSync()

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

  describe 'when a .js file starts with /* @flow */', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/flow-comment.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file does not start with 'use babel';", ->
    it "does not transpile it using babel", ->
      spyOn(console, 'error')
      expect(-> require('./fixtures/babel/invalid.js')).toThrow()

    it "does not try to log to stdout or stderr while parsing the file", ->
      spyOn(process.stderr, 'write')
      spyOn(process.stdout, 'write')

      transpiled = require('./fixtures/babel/babel-double-quotes.js')

      expect(process.stdout.write).not.toHaveBeenCalled()
      expect(process.stderr.write).not.toHaveBeenCalled()
