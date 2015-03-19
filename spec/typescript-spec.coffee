typescript = require '../src/typescript'
crypto = require 'crypto'

describe "TypeScript transpiler support", ->
  describe "::createTypeScriptVersionAndOptionsDigest", ->
    it "returns a digest for the library version and specified options", ->
      defaultOptions =
        target: 1 # ES5
        module: 'commonjs'
        sourceMap: true
      version = '1.4.1'
      shasum = crypto.createHash('sha1')
      shasum.update('typescript', 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update(version, 'utf8')
      shasum.update('\0', 'utf8')
      shasum.update(JSON.stringify(defaultOptions))
      expectedDigest = shasum.digest('hex')

      observedDigest = typescript.createTypeScriptVersionAndOptionsDigest(version, defaultOptions)
      expect(observedDigest).toEqual expectedDigest

  describe "when there is a .ts file", ->
    it "transpiles it using typescript", ->
      transpiled = require('./fixtures/typescript/valid.ts')
      expect(transpiled(3)).toBe 4

  describe "when the .ts file is invalid", ->
    it "does not transpile", ->
      expect(-> require('./fixtures/typescript/invalid.ts')).toThrow()
