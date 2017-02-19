DefaultDirectoryProvider = require '../src/default-directory-provider'
path = require 'path'
fs = require 'fs-plus'
temp = require('temp').track()

describe "DefaultDirectoryProvider", ->
  tmp = null

  beforeEach ->
    tmp = temp.mkdirSync('atom-spec-default-dir-provider')

  afterEach ->
    temp.cleanupSync()

  describe ".directoryForURISync(uri)", ->
    it "returns a Directory with a path that matches the uri", ->
      provider = new DefaultDirectoryProvider()

      directory = provider.directoryForURISync(tmp)
      expect(directory.getPath()).toEqual tmp

    it "normalizes its input before creating a Directory for it", ->
      provider = new DefaultDirectoryProvider()
      nonNormalizedPath = tmp + path.sep +  ".." + path.sep + path.basename(tmp)
      expect(tmp.includes("..")).toBe false
      expect(nonNormalizedPath.includes("..")).toBe true

      directory = provider.directoryForURISync(nonNormalizedPath)
      expect(directory.getPath()).toEqual tmp

    it "normalizes disk drive letter in Windows path", ->
      provider = new DefaultDirectoryProvider()
      nonNormalizedPath = tmp[0].toLowerCase()+tmp.slice(1)
      expect(!tmp.search(/^[a-z]:/)).toBe false
      expect(!nonNormalizedPath.search(/^[a-z]:/)).toBe true

      directory = provider.directoryForURISync(nonNormalizedPath)
      expect(directory.getPath()).toEqual tmp

    it "creates a Directory for its parent dir when passed a file", ->
      provider = new DefaultDirectoryProvider()
      file = path.join(tmp, "example.txt")
      fs.writeFileSync(file, "data")

      directory = provider.directoryForURISync(file)
      expect(directory.getPath()).toEqual tmp

    it "creates a Directory with a path as a uri when passed a uri", ->
      provider = new DefaultDirectoryProvider()
      uri = 'remote://server:6792/path/to/a/dir'
      directory = provider.directoryForURISync(uri)
      expect(directory.getPath()).toEqual uri

  describe ".directoryForURI(uri)", ->
    it "returns a Promise that resolves to a Directory with a path that matches the uri", ->
      provider = new DefaultDirectoryProvider()

      waitsForPromise ->
        provider.directoryForURI(tmp).then (directory) ->
          expect(directory.getPath()).toEqual tmp
