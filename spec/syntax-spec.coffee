path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'

describe "the `syntax` global", ->
  beforeEach ->

    waitsForPromise ->
      atom.packages.activatePackage('language-text')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-coffee-script')

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

  describe "serialization", ->
    it "remembers grammar overrides by path", ->
      filePath = '/foo/bar/file.js'
      expect(atom.syntax.selectGrammar(filePath).name).not.toBe 'Ruby'
      atom.syntax.setGrammarOverrideForPath(filePath, 'source.ruby')
      syntax2 = atom.deserializers.deserialize(atom.syntax.serialize())
      syntax2.addGrammar(grammar) for grammar in atom.syntax.grammars when grammar isnt atom.syntax.nullGrammar
      expect(syntax2.selectGrammar(filePath).name).toBe 'Ruby'

  describe ".selectGrammar(filePath)", ->
    it "can use the filePath to load the correct grammar based on the grammar's filetype", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-git')

      runs ->
        expect(atom.syntax.selectGrammar("file.js").name).toBe "JavaScript" # based on extension (.js)
        expect(atom.syntax.selectGrammar(path.join(temp.dir, '.git', 'config')).name).toBe "Git Config" # based on end of the path (.git/config)
        expect(atom.syntax.selectGrammar("Rakefile").name).toBe "Ruby" # based on the file's basename (Rakefile)
        expect(atom.syntax.selectGrammar("curb").name).toBe "Null Grammar"
        expect(atom.syntax.selectGrammar("/hu.git/config").name).toBe "Null Grammar"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("./fixtures/shebang")
      expect(atom.syntax.selectGrammar(filePath).name).toBe "Ruby"

    it "uses the number of newlines in the first line regex to determine the number of lines to test against", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-property-list')

      runs ->
        fileContent = "first-line\n<html>"
        expect(atom.syntax.selectGrammar("dummy.coffee", fileContent).name).toBe "CoffeeScript"

        fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
        expect(atom.syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Null Grammar"

        fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        expect(atom.syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Property List (XML)"

    it "doesn't read the file when the file contents are specified", ->
      filePath = require.resolve("./fixtures/shebang")
      filePathContents = fs.readFileSync(filePath, 'utf8')
      spyOn(fs, 'read').andCallThrough()
      expect(atom.syntax.selectGrammar(filePath, filePathContents).name).toBe "Ruby"
      expect(fs.read).not.toHaveBeenCalled()

    it "allows the default grammar to be overridden for a path", ->
      filePath = '/foo/bar/file.js'
      expect(atom.syntax.selectGrammar(filePath).name).not.toBe 'Ruby'
      atom.syntax.setGrammarOverrideForPath(filePath, 'source.ruby')
      expect(atom.syntax.selectGrammar(filePath).name).toBe 'Ruby'
      atom.syntax.clearGrammarOverrideForPath(filePath)
      expect(atom.syntax.selectGrammar(filePath).name).not.toBe 'Ruby'

    describe "when multiple grammars have matching fileTypes", ->
      it "selects the grammar with the longest fileType match", ->
        grammarPath1 = temp.path(suffix: '.json')
        fs.writeFileSync grammarPath1, JSON.stringify(
          name: 'test1'
          scopeName: 'source1'
          fileTypes: ['test']
        )
        grammar1 = atom.syntax.loadGrammarSync(grammarPath1)
        expect(atom.syntax.selectGrammar('more.test', '')).toBe grammar1

        grammarPath2 = temp.path(suffix: '.json')
        fs.writeFileSync grammarPath2, JSON.stringify(
          name: 'test2'
          scopeName: 'source2'
          fileTypes: ['test', 'more.test']
        )
        grammar2 = atom.syntax.loadGrammarSync(grammarPath2)
        expect(atom.syntax.selectGrammar('more.test', '')).toBe grammar2

    describe "when there is no file path", ->
      it "does not throw an exception (regression)", ->
        expect(-> atom.syntax.selectGrammar(null, '#!/usr/bin/ruby')).not.toThrow()
        expect(-> atom.syntax.selectGrammar(null, '')).not.toThrow()
        expect(-> atom.syntax.selectGrammar(null, null)).not.toThrow()

  describe ".removeGrammar(grammar)", ->
    it "removes the grammar, so it won't be returned by selectGrammar", ->
      grammar = atom.syntax.selectGrammar('foo.js')
      atom.syntax.removeGrammar(grammar)
      expect(atom.syntax.selectGrammar('foo.js').name).not.toBe grammar.name

  describe ".getProperty(scopeDescriptor)", ->
    it "returns the property with the most specific scope selector", ->
      atom.syntax.addProperties(".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      atom.syntax.addProperties(".source .string.quoted.double", foo: bar: baz: 22)
      atom.syntax.addProperties(".source", foo: bar: baz: 11)

      expect(atom.syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
      expect(atom.syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBe 22
      expect(atom.syntax.getProperty([".source.js", ".variable.assignment.js"], "foo.bar.baz")).toBe 11
      expect(atom.syntax.getProperty([".text"], "foo.bar.baz")).toBeUndefined()

    it "favors the most recently added properties in the event of a specificity tie", ->
      atom.syntax.addProperties(".source.coffee .string.quoted.single", foo: bar: baz: 42)
      atom.syntax.addProperties(".source.coffee .string.quoted.double", foo: bar: baz: 22)

      expect(atom.syntax.getProperty([".source.coffee", ".string.quoted.single"], "foo.bar.baz")).toBe 42
      expect(atom.syntax.getProperty([".source.coffee", ".string.quoted.single.double"], "foo.bar.baz")).toBe 22

  describe ".removeProperties(name)", ->
    it "allows properties to be removed by name", ->
      atom.syntax.addProperties("a", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      atom.syntax.addProperties("b", ".source .string.quoted.double", foo: bar: baz: 22)

      atom.syntax.removeProperties("b")
      expect(atom.syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBeUndefined()
      expect(atom.syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
