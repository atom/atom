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
    expect(blobStore.get("foo")).toBeUndefined()
    expect(blobStore.get("bar")).toBeUndefined()

  it "allows to read and write buffers from/to memory without persisting them", ->
    blobStore.set("foo", Buffer.from("foo"))
    blobStore.set("bar", Buffer.from("bar"))

    expect(blobStore.get("foo")).toEqual(Buffer.from("foo"))
    expect(blobStore.get("bar")).toEqual(Buffer.from("bar"))

    expect(blobStore.get("baz")).toBeUndefined()
    expect(blobStore.get("qux")).toBeUndefined()

  it "persists buffers when saved and retrieves them on load, giving priority to in-memory ones", ->
    blobStore.set("foo", Buffer.from("foo"))
    blobStore.set("bar", Buffer.from("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo")).toEqual(Buffer.from("foo"))
    expect(blobStore.get("bar")).toEqual(Buffer.from("bar"))
    expect(blobStore.get("baz")).toBeUndefined()
    expect(blobStore.get("qux")).toBeUndefined()

    blobStore.set("foo", Buffer.from("changed"))

    expect(blobStore.get("foo")).toEqual(Buffer.from("changed"))

  it "persists in-memory and previously stored buffers, and deletes unused keys when saved", ->
    blobStore.set("foo", Buffer.from("foo"))
    blobStore.set("bar", Buffer.from("bar"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)
    blobStore.set("bar", Buffer.from("changed"))
    blobStore.set("qux", Buffer.from("qux"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("foo")).toBeUndefined()
    expect(blobStore.get("bar")).toEqual(Buffer.from("changed"))
    expect(blobStore.get("qux")).toEqual(Buffer.from("qux"))

  it "allows to delete keys from both memory and stored buffers", ->
    blobStore.set("a", Buffer.from("a"))
    blobStore.set("b", Buffer.from("b"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    blobStore.get("a") # prevent the key from being deleted on save
    blobStore.set("b", Buffer.from("b"))
    blobStore.set("c", Buffer.from("c"))
    blobStore.delete("b")
    blobStore.delete("c")
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a")).toEqual(Buffer.from("a"))
    expect(blobStore.get("b")).toBeUndefined()
    expect(blobStore.get("b")).toBeUndefined()
    expect(blobStore.get("c")).toBeUndefined()

  it "ignores errors when loading an invalid blob store", ->
    blobStore.set("a", Buffer.from("a"))
    blobStore.set("b", Buffer.from("b"))
    blobStore.save()

    # Simulate corruption
    fs.writeFileSync(path.join(storageDirectory, "MAP"), Buffer.from([0]))
    fs.writeFileSync(path.join(storageDirectory, "INVKEYS"), Buffer.from([0]))
    fs.writeFileSync(path.join(storageDirectory, "BLOB"), Buffer.from([0]))

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a")).toBeUndefined()
    expect(blobStore.get("b")).toBeUndefined()

    blobStore.set("a", Buffer.from("x"))
    blobStore.set("b", Buffer.from("y"))
    blobStore.save()

    blobStore = FileSystemBlobStore.load(storageDirectory)

    expect(blobStore.get("a")).toEqual(Buffer.from("x"))
    expect(blobStore.get("b")).toEqual(Buffer.from("y"))
