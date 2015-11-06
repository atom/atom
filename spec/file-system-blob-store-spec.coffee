temp = require 'temp'
FileSystemBlobStore = require '../src/file-system-blob-store'

describe "FileSystemBlobStore", ->
  [storageDirectory, blobStore] = []

  beforeEach ->
    storageDirectory = temp.path()
    blobStore = FileSystemBlobStore.load(storageDirectory)

  it "is empty when the file doesn't exist", ->
    expect(blobStore.get("foo")).toBeUndefined()
    expect(blobStore.get("bar")).toBeUndefined()

  it "allows to read and write buffers from/to memory without persisting them", ->
    blobStore.set("foo", new Buffer("foo"))
    blobStore.set("bar", new Buffer("bar"))

    expect(blobStore.get("foo")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar")).toEqual(new Buffer("bar"))

  it "persists buffers when saved and retrieves them on load, giving priority to in-memory ones", ->
    blobStore.set("foo", new Buffer("foo"))
    blobStore.set("bar", new Buffer("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar")).toEqual(new Buffer("bar"))

    blobStore.set("foo", new Buffer("changed"))

    expect(blobStore.get("foo")).toEqual(new Buffer("changed"))

  it "persists both in-memory and previously stored buffers when saved", ->
    blobStore.set("foo", new Buffer("foo"))
    blobStore.set("bar", new Buffer("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)
    blobStore.set("bar", new Buffer("changed"))
    blobStore.set("qux", new Buffer("qux"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo")).toEqual(new Buffer("foo"))
    expect(blobStore.get("bar")).toEqual(new Buffer("changed"))
    expect(blobStore.get("qux")).toEqual(new Buffer("qux"))

  it "allows to delete keys from both memory and stored buffers", ->
    blobStore.set("a", new Buffer("a"))
    blobStore.set("b", new Buffer("b"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    blobStore.set("b", new Buffer("b"))
    blobStore.set("c", new Buffer("c"))
    blobStore.delete("b")
    blobStore.delete("c")
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a")).toEqual(new Buffer("a"))
    expect(blobStore.get("b")).toBeUndefined()
    expect(blobStore.get("c")).toBeUndefined()
