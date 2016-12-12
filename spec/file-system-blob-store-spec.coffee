temp = require('temp').track()
path = require 'path'
fs = require 'fs-plus'
FileSystemBlobStore = require '../src/file-system-blob-store'

describe "FileSystemBlobStore", ->
  [storageDirectory, blobStore] = []

  beforeEach ->
    storageDirectory = temp.path('atom-spec-filesystemblobstore')
    blobStore = FileSystemBlobStore.load(storageDirectory)

  afterEach ->
    fs.removeSync(storageDirectory)

  it "is empty when the file doesn't exist", ->
    expect(blobStore.get("foo", "invalidation-key-1")).toBeUndefined()
    expect(blobStore.get("bar", "invalidation-key-2")).toBeUndefined()

  it "allows to read and write buffers from/to memory without persisting them", ->
    blobStore.set("foo", "invalidation-key-1", new Buffer("foo"))
    blobStore.set("bar", "invalidation-key-2", new Buffer("bar"))

    expect(blobStore.get("foo", "invalidation-key-1")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar", "invalidation-key-2")).toEqual(new Buffer("bar"))

    expect(blobStore.get("foo", "unexisting-key")).toBeUndefined()
    expect(blobStore.get("bar", "unexisting-key")).toBeUndefined()

  it "persists buffers when saved and retrieves them on load, giving priority to in-memory ones", ->
    blobStore.set("foo", "invalidation-key-1", new Buffer("foo"))
    blobStore.set("bar", "invalidation-key-2", new Buffer("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo", "invalidation-key-1")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar", "invalidation-key-2")).toEqual(new Buffer("bar"))
    expect(blobStore.get("foo", "unexisting-key")).toBeUndefined()
    expect(blobStore.get("bar", "unexisting-key")).toBeUndefined()

    blobStore.set("foo", "new-key", new Buffer("changed"))

    expect(blobStore.get("foo", "new-key")).toEqual(new Buffer("changed"))
    expect(blobStore.get("foo", "invalidation-key-1")).toBeUndefined()

  it "persists both in-memory and previously stored buffers when saved", ->
    blobStore.set("foo", "invalidation-key-1", new Buffer("foo"))
    blobStore.set("bar", "invalidation-key-2", new Buffer("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)
    blobStore.set("bar", "invalidation-key-3", new Buffer("changed"))
    blobStore.set("qux", "invalidation-key-4", new Buffer("qux"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo", "invalidation-key-1")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar", "invalidation-key-3")).toEqual(new Buffer("changed"))
    expect(blobStore.get("qux", "invalidation-key-4")).toEqual(new Buffer("qux"))
    expect(blobStore.get("foo", "unexisting-key")).toBeUndefined()
    expect(blobStore.get("bar", "invalidation-key-2")).toBeUndefined()
    expect(blobStore.get("qux", "unexisting-key")).toBeUndefined()

  it "allows to delete keys from both memory and stored buffers", ->
    blobStore.set("a", "invalidation-key-1", new Buffer("a"))
    blobStore.set("b", "invalidation-key-2", new Buffer("b"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    blobStore.set("b", "invalidation-key-3", new Buffer("b"))
    blobStore.set("c", "invalidation-key-4", new Buffer("c"))
    blobStore.delete("b")
    blobStore.delete("c")
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a", "invalidation-key-1")).toEqual(new Buffer("a"))
    expect(blobStore.get("b", "invalidation-key-2")).toBeUndefined()
    expect(blobStore.get("b", "invalidation-key-3")).toBeUndefined()
    expect(blobStore.get("c", "invalidation-key-4")).toBeUndefined()

  it "ignores errors when loading an invalid blob store", ->
    blobStore.set("a", "invalidation-key-1", new Buffer("a"))
    blobStore.set("b", "invalidation-key-2", new Buffer("b"))
    blobStore.save()

    # Simulate corruption
    fs.writeFileSync(path.join(storageDirectory, "MAP"), new Buffer([0]))
    fs.writeFileSync(path.join(storageDirectory, "INVKEYS"), new Buffer([0]))
    fs.writeFileSync(path.join(storageDirectory, "BLOB"), new Buffer([0]))

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a", "invalidation-key-1")).toBeUndefined()
    expect(blobStore.get("b", "invalidation-key-2")).toBeUndefined()

    blobStore.set("a", "invalidation-key-1", new Buffer("x"))
    blobStore.set("b", "invalidation-key-2", new Buffer("y"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a", "invalidation-key-1")).toEqual(new Buffer("x"))
    expect(blobStore.get("b", "invalidation-key-2")).toEqual(new Buffer("y"))
