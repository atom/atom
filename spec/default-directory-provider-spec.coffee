DefaultDirectoryProvider = require "../src/default-directory-provider"
path = require "path"
temp = require "temp"

describe "DefaultDirectoryProvider", ->
  describe ".directoryForURISync(uri)", ->
    it "returns a Directory with a path that matches the uri", ->
      provider = new DefaultDirectoryProvider()
      tmp = temp.mkdirSync()

      directory = provider.directoryForURISync(tmp)
      expect(directory.getPath()).toEqual tmp

    it "normalizes its input before creating a Directory for it", ->
      provider = new DefaultDirectoryProvider()
      tmp = temp.mkdirSync()
      nonNormalizedPath = tmp + path.sep +  ".." + path.sep + path.basename(tmp)
      expect(tmp.includes("..")).toBe false
      expect(nonNormalizedPath.includes("..")).toBe true

      directory = provider.directoryForURISync(nonNormalizedPath)
      expect(directory.getPath()).toEqual tmp

    it "creates a Directory for its parent dir when passed a file", ->
      provider = new DefaultDirectoryProvider()
      tmp = temp.mkdirSync()
      file = path.join(tmp, "example.txt")
      fs.writeFileSync(file, "data")

      directory = provider.directoryForURISync(file)
      expect(directory.getPath()).toEqual tmp

  describe ".directoryForURI(uri)", ->
    it "returns a Promise that resolves to a Directory with a path that matches the uri", ->
      provider = new DefaultDirectoryProvider()
      tmp = temp.mkdirSync()

      waitsForPromise ->
        provider.directoryForURI(tmp).then (directory) ->
          expect(directory.getPath()).toEqual tmp
