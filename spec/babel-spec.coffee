babel = require '../src/babel'
crypto = require 'crypto'
grim = require 'grim'

describe "Babel transpiler support", ->
  beforeEach ->
    jasmine.snapshotDeprecations()

  afterEach ->
    jasmine.restoreDeprecationsSnapshot()

  describe "::createBabelVersionAndOptionsDigest", ->
    it "returns a digest for the library version and specified options", ->
      defaultOptions =
        blacklist: [
          'useStrict'
        ]
        experimental: true
        optional: [
          'asyncToGenerator'
        ]
        reactCompat: true
        sourceMap: 'inline'
      version = '3.0.14'
      shasum = crypto.createHash('sha1')
      shasum.update('babel-core', 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update(version, 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update('{"blacklist": ["useStrict",],"experimental": true,"optional": ["asyncToGenerator",],"reactCompat": true,"sourceMap": "inline",}')
      expectedDigest = shasum.digest('hex')

      observedDigest = babel.createBabelVersionAndOptionsDigest(version, defaultOptions)
      expect(observedDigest).toEqual expectedDigest

  describe "when a .js file starts with 'use babel';", ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-single-quotes.js')
      expect(transpiled(3)).toBe 4
      expect(grim.getDeprecationsLength()).toBe 0

  describe "when a .js file starts with 'use 6to5';", ->
    it "transpiles it using babel and adds a pragma deprecation", ->
      expect(grim.getDeprecationsLength()).toBe 0
      transpiled = require('./fixtures/babel/6to5-single-quotes.js')
      expect(transpiled(3)).toBe 4
      expect(grim.getDeprecationsLength()).toBe 1

  describe 'when a .js file starts with "use babel";', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-double-quotes.js')
      expect(transpiled(3)).toBe 4
      expect(grim.getDeprecationsLength()).toBe 0

  describe 'when a .js file starts with "use 6to5";', ->
    it "transpiles it using babel and adds a pragma deprecation", ->
      expect(grim.getDeprecationsLength()).toBe 0
      transpiled = require('./fixtures/babel/6to5-double-quotes.js')
      expect(transpiled(3)).toBe 4
      expect(grim.getDeprecationsLength()).toBe 1

  describe "when a .js file does not start with 'use 6to6';", ->
    it "does not transpile it using babel", ->
      expect(-> require('./fixtures/babel/invalid.js')).toThrow()
