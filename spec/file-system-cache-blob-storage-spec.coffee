temp = require 'temp'
FileSystemCacheBlobStorage = require '../src/file-system-cache-blob-storage'

describe "FileSystemCacheBlobStorage", ->
  [storageDirectory, cacheBlobStorage] = []

  beforeEach ->
    storageDirectory = temp.path()
    cacheBlobStorage = FileSystemCacheBlobStorage.load(storageDirectory)

  it "is empty when the file doesn't exist", ->
    expect(cacheBlobStorage.get("foo")).toBeUndefined()
    expect(cacheBlobStorage.get("bar")).toBeUndefined()

  it "allows to read and write buffers from/to memory without persisting them", ->
    cacheBlobStorage.set("foo", new Buffer("foo"))
    cacheBlobStorage.set("bar", new Buffer("bar"))

    expect(cacheBlobStorage.get("foo")).toEqual(new Buffer("foo"))
    expect(cacheBlobStorage.get("bar")).toEqual(new Buffer("bar"))

  it "persists buffers when saved and retrieves them on load, giving priority to in-memory ones", ->
    cacheBlobStorage.set("foo", new Buffer("foo"))
    cacheBlobStorage.set("bar", new Buffer("bar"))
    cacheBlobStorage.save()

    cacheBlobStorage = FileSystemCacheBlobStorage.load(storageDirectory)

    expect(cacheBlobStorage.get("foo")).toEqual(new Buffer("foo"))
    expect(cacheBlobStorage.get("bar")).toEqual(new Buffer("bar"))

    cacheBlobStorage.set("foo", new Buffer("changed"))

    expect(cacheBlobStorage.get("foo")).toEqual(new Buffer("changed"))

  it "persists both in-memory and previously stored buffers when saved", ->
    cacheBlobStorage.set("foo", new Buffer("foo"))
    cacheBlobStorage.set("bar", new Buffer("bar"))
    cacheBlobStorage.save()

    cacheBlobStorage = FileSystemCacheBlobStorage.load(storageDirectory)
    cacheBlobStorage.set("bar", new Buffer("changed"))
    cacheBlobStorage.set("qux", new Buffer("qux"))
    cacheBlobStorage.save()

    cacheBlobStorage = FileSystemCacheBlobStorage.load(storageDirectory)

    expect(cacheBlobStorage.get("foo")).toEqual(new Buffer("foo"))
    expect(cacheBlobStorage.get("bar")).toEqual(new Buffer("changed"))
    expect(cacheBlobStorage.get("qux")).toEqual(new Buffer("qux"))
