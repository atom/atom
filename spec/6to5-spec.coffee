to5 = require '../src/6to5'
crypto = require 'crypto'

describe "6to5 transpiler support", ->
  describe "::create6to5VersionAndOptionsDigest", ->
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
      shasum.update('6to5-core', 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update(version, 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update('{"blacklist": ["useStrict",],"experimental": true,"optional": ["asyncToGenerator",],"reactCompat": true,"sourceMap": "inline",}')
      expectedDigest = shasum.digest('hex')

      observedDigest = to5.create6to5VersionAndOptionsDigest(version, defaultOptions)
      expect(observedDigest).toEqual expectedDigest

  describe "when a .js file starts with 'use 6to5';", ->
    it "transpiles it using 6to5", ->
      transpiled = require('./fixtures/6to5/single-quotes.js')
      expect(transpiled(3)).toBe 4

  describe 'when a .js file starts with "use 6to5";', ->
    it "transpiles it using 6to5", ->
      transpiled = require('./fixtures/6to5/double-quotes.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file does not start with 'use 6to6';", ->
    it "does not transpile it using 6to5", ->
      expect(-> require('./fixtures/6to5/invalid.js')).toThrow()
