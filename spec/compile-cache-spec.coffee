path = require 'path'
temp = require('temp').track()
Babel = require 'babel-core'
CoffeeScript = require 'coffee-script'
{TypeScriptSimple} = require 'typescript-simple'
CSON = require 'season'
CompileCache = require '../src/compile-cache'

describe 'CompileCache', ->
  [atomHome, fixtures] = []

  beforeEach ->
    fixtures = atom.project.getPaths()[0]
    atomHome = temp.mkdirSync('fake-atom-home')

    CSON.setCacheDir(null)
    CompileCache.resetCacheStats()

    spyOn(Babel, 'transform').andReturn {code: 'the-babel-code'}
    spyOn(CoffeeScript, 'compile').andReturn 'the-coffee-code'
    spyOn(TypeScriptSimple::, 'compile').andReturn 'the-typescript-code'

  afterEach ->
    CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)
    CSON.setCacheDir(CompileCache.getCacheDirectory())
    try
      temp.cleanupSync()

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
        spyOn(CSON, 'setCacheDir').andCallThrough()
        spyOn(CSON, 'readFileSync').andCallThrough()

        CompileCache.addPathToCache(path.join(fixtures, 'cson.cson'), atomHome)
        expect(CSON.readFileSync).toHaveBeenCalledWith(path.join(fixtures, 'cson.cson'))
        expect(CSON.setCacheDir).toHaveBeenCalledWith(path.join(atomHome, '/compile-cache'))

        CSON.readFileSync.reset()
        CSON.setCacheDir.reset()
        CompileCache.addPathToCache(path.join(fixtures, 'cson.cson'), atomHome)
        expect(CSON.readFileSync).toHaveBeenCalledWith(path.join(fixtures, 'cson.cson'))
        expect(CSON.setCacheDir).not.toHaveBeenCalled()

  describe 'overriding Error.prepareStackTrace', ->
    it 'removes the override on the next tick, and always assigns the raw stack', ->
      return if process.platform is 'win32' # Flakey Error.stack contents on Win32

      Error.prepareStackTrace = -> 'a-stack-trace'

      error = new Error("Oops")
      expect(error.stack).toBe 'a-stack-trace'
      expect(Array.isArray(error.getRawStack())).toBe true

      waits(1)
      runs ->
        error = new Error("Oops again")
        expect(error.stack).toContain('compile-cache-spec.coffee')
        expect(Array.isArray(error.getRawStack())).toBe true

    it 'does not infinitely loop when the original prepareStackTrace value is reassigned', ->
      originalPrepareStackTrace = Error.prepareStackTrace

      Error.prepareStackTrace = -> 'a-stack-trace'
      Error.prepareStackTrace = originalPrepareStackTrace

      error = new Error('Oops')
      expect(error.stack).toContain('compile-cache-spec.coffee')
      expect(Array.isArray(error.getRawStack())).toBe true

    it 'does not infinitely loop when the assigned prepareStackTrace calls the original prepareStackTrace', ->
      originalPrepareStackTrace = Error.prepareStackTrace

      Error.prepareStackTrace = (error, stack) ->
        error.foo = 'bar'
        originalPrepareStackTrace(error, stack)

      error = new Error('Oops')
      expect(error.stack).toContain('compile-cache-spec.coffee')
      expect(error.foo).toBe('bar')
      expect(Array.isArray(error.getRawStack())).toBe true
