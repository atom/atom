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

  describe ".directoryForURI(uri)", ->
    it "returns a Promise that resolves to a Directory with a path that matches the uri", ->
      provider = new DefaultDirectoryProvider()
      tmp = temp.mkdirSync()

      waitsForPromise ->
        provider.directoryForURI(tmp).then (directory) ->
          expect(directory.getPath()).toEqual tmp
