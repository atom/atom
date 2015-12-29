fs = require 'fs'
path = require 'path'
Module = require 'module'

describe "NativeCompileCache", ->
  nativeCompileCache = require '../src/native-compile-cache'
  [fakeCacheStore, cachedFiles] = []

  beforeEach ->
    cachedFiles = []
    fakeCacheStore = jasmine.createSpyObj("cache store", ["set", "get", "has", "delete"])
    fakeCacheStore.has.andCallFake (cacheKey, invalidationKey) ->
      fakeCacheStore.get(cacheKey, invalidationKey)?
    fakeCacheStore.get.andCallFake (cacheKey, invalidationKey) ->
      for entry in cachedFiles by -1
        continue if entry.cacheKey isnt cacheKey
        continue if entry.invalidationKey isnt invalidationKey
        return entry.cacheBuffer
      return
    fakeCacheStore.set.andCallFake (cacheKey, invalidationKey, cacheBuffer) ->
      cachedFiles.push({cacheKey, invalidationKey, cacheBuffer})

    nativeCompileCache.setCacheStore(fakeCacheStore)
    nativeCompileCache.setV8Version("a-v8-version")
    nativeCompileCache.install()

  it "writes and reads from the cache storage when requiring files", ->
    fn1 = require('./fixtures/native-cache/file-1')
    fn2 = require('./fixtures/native-cache/file-2')

    expect(cachedFiles.length).toBe(2)

    expect(cachedFiles[0].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-1'))
    expect(cachedFiles[0].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[0].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn1()).toBe(1)

    expect(cachedFiles[1].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-2'))
    expect(cachedFiles[1].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[1].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn2()).toBe(2)

    delete Module._cache[require.resolve('./fixtures/native-cache/file-1')]
    fn1 = require('./fixtures/native-cache/file-1')
    expect(cachedFiles.length).toBe(2)
    expect(fn1()).toBe(1)

  describe "when v8 version changes", ->
    it "updates the cache of previously required files", ->
      nativeCompileCache.setV8Version("version-1")
      fn4 = require('./fixtures/native-cache/file-4')

      expect(cachedFiles.length).toBe(1)
      expect(cachedFiles[0].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-4'))
      expect(cachedFiles[0].cacheBuffer).toBeInstanceOf(Uint8Array)
      expect(cachedFiles[0].cacheBuffer.length).toBeGreaterThan(0)
      expect(fn4()).toBe("file-4")

      nativeCompileCache.setV8Version("version-2")
      delete Module._cache[require.resolve('./fixtures/native-cache/file-4')]
      fn4 = require('./fixtures/native-cache/file-4')

      expect(cachedFiles.length).toBe(2)
      expect(cachedFiles[1].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-4'))
      expect(cachedFiles[1].invalidationKey).not.toBe(cachedFiles[0].invalidationKey)
      expect(cachedFiles[1].cacheBuffer).toBeInstanceOf(Uint8Array)
      expect(cachedFiles[1].cacheBuffer.length).toBeGreaterThan(0)

  describe "when a previously required and cached file changes", ->
    beforeEach ->
      fs.writeFileSync path.resolve('./spec/fixtures/native-cache/file-5'), """
      module.exports = function () { return "file-5" }
      """

    afterEach ->
      fs.unlinkSync path.resolve('./spec/fixtures/native-cache/file-5')

    it "removes it from the store and re-inserts it with the new cache", ->
      fn5 = require('./fixtures/native-cache/file-5')

      expect(cachedFiles.length).toBe(1)
      expect(cachedFiles[0].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-5'))
      expect(cachedFiles[0].cacheBuffer).toBeInstanceOf(Uint8Array)
      expect(cachedFiles[0].cacheBuffer.length).toBeGreaterThan(0)
      expect(fn5()).toBe("file-5")

      delete Module._cache[require.resolve('./fixtures/native-cache/file-5')]
      fs.appendFileSync(require.resolve('./fixtures/native-cache/file-5'), "\n\n")
      fn5 = require('./fixtures/native-cache/file-5')

      expect(cachedFiles.length).toBe(2)
      expect(cachedFiles[1].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-5'))
      expect(cachedFiles[1].invalidationKey).not.toBe(cachedFiles[0].invalidationKey)
      expect(cachedFiles[1].cacheBuffer).toBeInstanceOf(Uint8Array)
      expect(cachedFiles[1].cacheBuffer.length).toBeGreaterThan(0)

  it "deletes previously cached code when the cache is an invalid file", ->
    fakeCacheStore.has.andReturn(true)
    fakeCacheStore.get.andCallFake -> new Buffer("an invalid cache")

    fn3 = require('./fixtures/native-cache/file-3')

    expect(fakeCacheStore.delete).toHaveBeenCalledWith(require.resolve('./fixtures/native-cache/file-3'))
    expect(fn3()).toBe(3)
