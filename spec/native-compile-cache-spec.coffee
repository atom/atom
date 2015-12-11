describe "NativeCompileCache", ->
  nativeCompileCache = require '../src/native-compile-cache'
  [fakeCacheStore, cachedFiles] = []

  beforeEach ->
    cachedFiles = []
    fakeCacheStore = jasmine.createSpyObj("cache store", ["set", "get", "has", "delete"])
    nativeCompileCache.setCacheStore(fakeCacheStore)
    nativeCompileCache.install()

  it "writes and reads from the cache storage when requiring files", ->
    fakeCacheStore.has.andReturn(false)
    fakeCacheStore.set.andCallFake (cacheKey, invalidationKey, cacheBuffer) ->
      cachedFiles.push({cacheKey, cacheBuffer})

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

    fakeCacheStore.has.andReturn(true)
    fakeCacheStore.get.andReturn(cachedFiles[0].cacheBuffer)
    fakeCacheStore.set.reset()

    fn1 = require('./fixtures/native-cache/file-1')

    expect(fakeCacheStore.set).not.toHaveBeenCalled()
    expect(fn1()).toBe(1)

  it "deletes previously cached code when the cache is an invalid file", ->
    fakeCacheStore.has.andReturn(true)
    fakeCacheStore.get.andCallFake -> new Buffer("an invalid cache")

    fn3 = require('./fixtures/native-cache/file-3')

    expect(fakeCacheStore.delete.calls.length).toBe(1)
    expect(fakeCacheStore.delete.calls[0].args[0]).toBe(require.resolve('./fixtures/native-cache/file-3'))
    expect(fn3()).toBe(3)
