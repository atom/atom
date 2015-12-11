fs = require 'fs'
path = require 'path'

describe "NativeCompileCache", ->
  nativeCompileCache = require '../src/native-compile-cache'
  [fakeCacheStore, cachedFiles] = []

  beforeEach ->
    cachedFiles = []
    fakeCacheStore = jasmine.createSpyObj("cache store", ["set", "get", "has", "delete"])
    nativeCompileCache.setCacheStore(fakeCacheStore)
    nativeCompileCache.install()

    fs.writeFileSync path.resolve('./spec/fixtures/native-cache/file-4'), """
    module.exports = function () { return "file-4" }
    """

  afterEach ->
    fs.unlinkSync path.resolve('./spec/fixtures/native-cache/file-4')

  it "writes and reads from the cache storage when requiring files", ->
    fakeCacheStore.has.andCallFake (cacheKey, invalidationKey) ->
      fakeCacheStore.get(cacheKey, invalidationKey)?
    fakeCacheStore.get.andCallFake (cacheKey, invalidationKey) ->
      for entry in cachedFiles
        continue if entry.cacheKey isnt cacheKey
        continue if entry.invalidationKey isnt invalidationKey
        return entry.cacheBuffer
      return
    fakeCacheStore.set.andCallFake (cacheKey, invalidationKey, cacheBuffer) ->
      cachedFiles.push({cacheKey, invalidationKey, cacheBuffer})

    fn1 = require('./fixtures/native-cache/file-1')
    fn2 = require('./fixtures/native-cache/file-2')
    fn4 = require('./fixtures/native-cache/file-4')

    expect(cachedFiles.length).toBe(3)

    expect(cachedFiles[0].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-1'))
    expect(cachedFiles[0].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[0].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn1()).toBe(1)

    expect(cachedFiles[1].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-2'))
    expect(cachedFiles[1].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[1].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn2()).toBe(2)

    expect(cachedFiles[2].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-4'))
    expect(cachedFiles[2].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[2].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn4()).toBe("file-4")

    fs.appendFileSync(require.resolve('./fixtures/native-cache/file-4'), "\n")
    delete require('module')._cache[require.resolve('./fixtures/native-cache/file-1')]
    delete require('module')._cache[require.resolve('./fixtures/native-cache/file-4')]
    fn1 = require('./fixtures/native-cache/file-1')
    fn4 = require('./fixtures/native-cache/file-4')

    # file content has changed, ensure we create a new cache entry
    expect(cachedFiles.length).toBe(4)
    expect(cachedFiles[3].cacheKey).toBe(require.resolve('./fixtures/native-cache/file-4'))
    expect(cachedFiles[3].invalidationKey).not.toBe(cachedFiles[2].invalidationKey)
    expect(cachedFiles[3].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[3].cacheBuffer.length).toBeGreaterThan(0)

    expect(fn1()).toBe(1)
    expect(fn4()).toBe("file-4")

  it "deletes previously cached code when the cache is an invalid file", ->
    fakeCacheStore.has.andReturn(true)
    fakeCacheStore.get.andCallFake -> new Buffer("an invalid cache")

    fn3 = require('./fixtures/native-cache/file-3')

    expect(fakeCacheStore.delete).toHaveBeenCalledWith(require.resolve('./fixtures/native-cache/file-3'))
    expect(fn3()).toBe(3)
