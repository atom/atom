{fs} = require 'atom'
path = require 'path'
temp = require 'temp'
TextMateGrammar = require '../src/text-mate-grammar'

describe "the `syntax` global", ->
  beforeEach ->
    atom.activatePackage('language-text', sync: true)
    atom.activatePackage('language-javascript', sync: true)
    atom.activatePackage('language-coffee-script', sync: true)
    atom.activatePackage('language-ruby', sync: true)

  describe "serialization", ->
    it "remembers grammar overrides by path", ->
      filePath = '/foo/bar/file.js'
      expect(syntax.selectGrammar(filePath).name).not.toBe 'Ruby'
      syntax.setGrammarOverrideForPath(filePath, 'source.ruby')
      syntax2 = deserialize(syntax.serialize())
      syntax2.addGrammar(grammar) for grammar in syntax.grammars when grammar isnt syntax.nullGrammar
      expect(syntax2.selectGrammar(filePath).name).toBe 'Ruby'

  describe ".selectGrammar(filePath)", ->
    it "can use the filePath to load the correct grammar based on the grammar's filetype", ->
      atom.activatePackage('language-git', sync: true)

      expect(syntax.selectGrammar("file.js").name).toBe "JavaScript" # based on extension (.js)
      expect(syntax.selectGrammar(path.join(temp.dir, '.git', 'config')).name).toBe "Git Config" # based on end of the path (.git/config)
      expect(syntax.selectGrammar("Rakefile").name).toBe "Ruby" # based on the file's basename (Rakefile)
      expect(syntax.selectGrammar("curb").name).toBe "Null Grammar"
      expect(syntax.selectGrammar("/hu.git/config").name).toBe "Null Grammar"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("./fixtures/shebang")
      expect(syntax.selectGrammar(filePath).name).toBe "Ruby"

    it "uses the number of newlines in the first line regex to determine the number of lines to test against", ->
      atom.activatePackage('language-property-list', sync: true)

      fileContent = "first-line\n<html>"
      expect(syntax.selectGrammar("dummy.coffee", fileContent).name).toBe "CoffeeScript"

      fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
      expect(syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Null Grammar"

      fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      expect(syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Property List (XML)"

    it "doesn't read the file when the file contents are specified", ->
      filePath = require.resolve("./fixtures/shebang")
      filePathContents = fs.read(filePath)
      spyOn(fs, 'read').andCallThrough()
      expect(syntax.selectGrammar(filePath, filePathContents).name).toBe "Ruby"
      expect(fs.read).not.toHaveBeenCalled()

    it "allows the default grammar to be overridden for a path", ->
      filePath = '/foo/bar/file.js'
      expect(syntax.selectGrammar(filePath).name).not.toBe 'Ruby'
      syntax.setGrammarOverrideForPath(filePath, 'source.ruby')
      expect(syntax.selectGrammar(filePath).name).toBe 'Ruby'
      syntax.clearGrammarOverrideForPath(filePath)
      expect(syntax.selectGrammar(filePath).name).not.toBe 'Ruby'

    describe "when multiple grammars have matching fileTypes", ->
      it "selects the grammar with the longest fileType match", ->
        grammar1 = new TextMateGrammar
          name: 'test1'
          scopeName: 'source1'
          fileTypes: ['test', 'more.test']

        grammar2 = new TextMateGrammar
          name: 'test2'
          scopeName: 'source2'
          fileTypes: ['test']

        syntax.addGrammar(grammar1)
        syntax.addGrammar(grammar2)

        expect(syntax.selectGrammar('more.test', '')).toBe grammar1

    describe "when there is no file path", ->
      it "does not throw an exception (regression)", ->
        expect(-> syntax.selectGrammar(null, '#!/usr/bin/ruby')).not.toThrow()
        expect(-> syntax.selectGrammar(null, '')).not.toThrow()
        expect(-> syntax.selectGrammar(null, null)).not.toThrow()

  describe ".removeGrammar(grammar)", ->
    it "removes the grammar, so it won't be returned by selectGrammar", ->
      grammar = syntax.selectGrammar('foo.js')
      syntax.removeGrammar(grammar)
      expect(syntax.selectGrammar('foo.js').name).not.toBe grammar.name

  describe ".getProperty(scopeDescriptor)", ->
    it "returns the property with the most specific scope selector", ->
      syntax.addProperties(".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      syntax.addProperties(".source .string.quoted.double", foo: bar: baz: 22)
      syntax.addProperties(".source", foo: bar: baz: 11)

      expect(syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
      expect(syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBe 22
      expect(syntax.getProperty([".source.js", ".variable.assignment.js"], "foo.bar.baz")).toBe 11
      expect(syntax.getProperty([".text"], "foo.bar.baz")).toBeUndefined()

    it "favors the most recently added properties in the event of a specificity tie", ->
      syntax.addProperties(".source.coffee .string.quoted.single", foo: bar: baz: 42)
      syntax.addProperties(".source.coffee .string.quoted.double", foo: bar: baz: 22)

      expect(syntax.getProperty([".source.coffee", ".string.quoted.single"], "foo.bar.baz")).toBe 42
      expect(syntax.getProperty([".source.coffee", ".string.quoted.single.double"], "foo.bar.baz")).toBe 22

  describe ".removeProperties(name)", ->
    it "allows properties to be removed by name", ->
      syntax.addProperties("a", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      syntax.addProperties("b", ".source .string.quoted.double", foo: bar: baz: 22)

      syntax.removeProperties("b")
      expect(syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBeUndefined()
      expect(syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
