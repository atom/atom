describe "NativeCompileCache", ->
  nativeCompileCache = require '../src/native-compile-cache'
  [fakeCacheStorage, cachedFiles] = []

  beforeEach ->
    cachedFiles = []
    fakeCacheStorage = jasmine.createSpyObj("cache storage", ["set", "get", "has", "delete"])
    nativeCompileCache.setCacheStorage(fakeCacheStorage)
    nativeCompileCache.install()

  it "writes and reads from the cache storage when requiring files", ->
    fakeCacheStorage.has.andReturn(false)
    fakeCacheStorage.set.andCallFake (filename, cacheBuffer) ->
      cachedFiles.push({filename, cacheBuffer})

    fn1 = require('./fixtures/native-cache/file-1')
    fn2 = require('./fixtures/native-cache/file-2')

    expect(cachedFiles.length).toBe(2)

    expect(cachedFiles[0].filename).toBe(require.resolve('./fixtures/native-cache/file-1'))
    expect(cachedFiles[0].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[0].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn1()).toBe(1)

    expect(cachedFiles[1].filename).toBe(require.resolve('./fixtures/native-cache/file-2'))
    expect(cachedFiles[1].cacheBuffer).toBeInstanceOf(Uint8Array)
    expect(cachedFiles[1].cacheBuffer.length).toBeGreaterThan(0)
    expect(fn2()).toBe(2)

    fakeCacheStorage.has.andReturn(true)
    fakeCacheStorage.get.andReturn(cachedFiles[0].cacheBuffer)
    fakeCacheStorage.set.reset()

    fn1 = require('./fixtures/native-cache/file-1')

    expect(fakeCacheStorage.set).not.toHaveBeenCalled()
    expect(fn1()).toBe(1)

  it "deletes previously cached code when the cache is not valid", ->
    fakeCacheStorage.has.andReturn(true)
    fakeCacheStorage.get.andCallFake -> new Buffer("an invalid cache")

    fn3 = require('./fixtures/native-cache/file-3')

    expect(fakeCacheStorage.delete).toHaveBeenCalledWith(require.resolve('./fixtures/native-cache/file-3'))
    expect(fn3()).toBe(3)
