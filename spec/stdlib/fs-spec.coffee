fs = require 'fs'

describe "fs", ->
  describe ".directory(path)", ->
    describe "when called with a file path", ->
      it "returns the path to the directory", ->
        expect(fs.directory(require.resolve('fixtures/dir/a'))).toBe require.resolve('fixtures/dir/')

    describe "when called with a directory path", ->
      it "return the path it was given", ->
        expect(fs.directory(require.resolve('fixtures/dir'))).toBe require.resolve('fixtures/dir/')
        expect(fs.directory(require.resolve('fixtures/dir/'))).toBe require.resolve('fixtures/dir/')

  describe ".join(paths...)", ->
    it "concatenates the given paths with the directory seperator", ->
      expect(fs.join('a')).toBe 'a'
      expect(fs.join('a', 'b', 'c')).toBe 'a/b/c'
      expect(fs.join('/a/b/', 'c', 'd')).toBe '/a/b/c/d'
      expect(fs.join('a', 'b/c/', 'd/')).toBe 'a/b/c/d/'

  describe ".async", ->
    directoryPath = null
    beforeEach ->
      directoryPath = require.resolve 'fixtures/dir'

    describe ".listTree(directoryPath)", ->
      it "returns a promise that resolves to the recursive contents of that directory", ->
        waitsForPromise ->
          fs.async.listTree(directoryPath).done (result) ->
            expect(result).toEqual fs.listTree(directoryPath)

    describe ".list(directoryPath)", ->
      it "returns a promise that resolves to the contents of that directory", ->
        waitsForPromise ->
          fs.async.list(directoryPath).done (result) ->
            expect(result).toEqual fs.list(directoryPath)

