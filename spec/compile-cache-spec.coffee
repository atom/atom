path = require 'path'
temp = require('temp').track()
Babel = require 'babel-core'
CoffeeScript = require 'coffee-script'
{TypeScriptSimple} = require 'typescript-simple'
CSON = require 'season'
CSONParser = require 'season/node_modules/cson-parser'
CompileCache = require '../src/compile-cache'

describe 'CompileCache', ->
  [atomHome, fixtures] = []

  beforeEach ->
    fixtures = atom.project.getPaths()[0]
    atomHome = temp.mkdirSync('fake-atom-home')

    CSON.setCacheDir(null)
    CompileCache.resetCacheStats()

    spyOn(Babel, 'transform').andReturn {code: 'the-babel-code'}
    spyOn(CoffeeScript, 'compile').andReturn {js: 'the-coffee-code', v3SourceMap: "{}"}
    spyOn(TypeScriptSimple::, 'compile').andReturn 'the-typescript-code'
    spyOn(CSONParser, 'parse').andReturn {the: 'cson-data'}

  afterEach ->
    CSON.setCacheDir(CompileCache.getCacheDirectory())
    CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

  describe 'addPathToCache(filePath, atomHome)', ->
    describe 'when the given file is plain javascript', ->
      it 'does not compile or cache the file', ->
        CompileCache.addPathToCache(path.join(fixtures, 'sample.js'), atomHome)
        expect(CompileCache.getCacheStats()['.js']).toEqual {hits: 0, misses: 0}

    describe 'when the given file uses babel', ->
      it 'compiles the file with babel and caches it', ->
        CompileCache.addPathToCache(path.join(fixtures, 'babel', 'babel-comment.js'), atomHome)
        expect(CompileCache.getCacheStats()['.js']).toEqual {hits: 0, misses: 1}
        expect(Babel.transform.callCount).toBe 1

        CompileCache.addPathToCache(path.join(fixtures, 'babel', 'babel-comment.js'), atomHome)
        expect(CompileCache.getCacheStats()['.js']).toEqual {hits: 1, misses: 1}
        expect(Babel.transform.callCount).toBe 1

    describe 'when the given file is coffee-script', ->
      it 'compiles the file with coffee-script and caches it', ->
        CompileCache.addPathToCache(path.join(fixtures, 'coffee.coffee'), atomHome)
        expect(CompileCache.getCacheStats()['.coffee']).toEqual {hits: 0, misses: 1}
        expect(CoffeeScript.compile.callCount).toBe 1

        CompileCache.addPathToCache(path.join(fixtures, 'coffee.coffee'), atomHome)
        expect(CompileCache.getCacheStats()['.coffee']).toEqual {hits: 1, misses: 1}
        expect(CoffeeScript.compile.callCount).toBe 1

    describe 'when the given file is typescript', ->
      it 'compiles the file with typescript and caches it', ->
        CompileCache.addPathToCache(path.join(fixtures, 'typescript', 'valid.ts'), atomHome)
        expect(CompileCache.getCacheStats()['.ts']).toEqual {hits: 0, misses: 1}
        expect(TypeScriptSimple::compile.callCount).toBe 1

        CompileCache.addPathToCache(path.join(fixtures, 'typescript', 'valid.ts'), atomHome)
        expect(CompileCache.getCacheStats()['.ts']).toEqual {hits: 1, misses: 1}
        expect(TypeScriptSimple::compile.callCount).toBe 1

    describe 'when the given file is CSON', ->
      it 'compiles the file to JSON and caches it', ->
        CompileCache.addPathToCache(path.join(fixtures, 'cson.cson'), atomHome)
        expect(CSONParser.parse.callCount).toBe 1

        CompileCache.addPathToCache(path.join(fixtures, 'cson.cson'), atomHome)
        expect(CSONParser.parse.callCount).toBe 1

  describe 'overriding Error.prepareStackTrace', ->
    it 'removes the override on the next tick, and always assigns the raw stack', ->
      Error.prepareStackTrace = -> 'a-stack-trace'

      error = new Error("Oops")
      expect(error.stack).toBe 'a-stack-trace'
      expect(Array.isArray(error.getRawStack())).toBe true

      waits(1)
      runs ->
        error = new Error("Oops again")
        console.log error.stack
        expect(error.stack).toContain('compile-cache-spec.coffee')
        expect(Array.isArray(error.getRawStack())).toBe true
