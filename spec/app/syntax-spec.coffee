fs = require 'fs-utils'

describe "the `syntax` global", ->
  describe ".selectGrammar(filePath)", ->
    it "can use the filePath to load the correct grammar based on the grammar's filetype", ->
      expect(syntax.selectGrammar("file.js").name).toBe "JavaScript" # based on extension (.js)
      expect(syntax.selectGrammar("/tmp/.git/config").name).toBe "Git Config" # based on end of the path (.git/config)
      expect(syntax.selectGrammar("Rakefile").name).toBe "Ruby" # based on the file's basename (Rakefile)
      expect(syntax.selectGrammar("curb").name).toBe "Plain Text"
      expect(syntax.selectGrammar("/hu.git/config").name).toBe "Plain Text"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("fixtures/shebang")
      expect(syntax.selectGrammar(filePath).name).toBe "Ruby"

    it "uses the number of newlines in the first line regex to determine the number of lines to test against", ->
      fileContent = "first-line\n<html>"
      expect(syntax.selectGrammar("dummy.coffee", fileContent).name).toBe "CoffeeScript"

      fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
      expect(syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Plain Text"

      fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      expect(syntax.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Property List (XML)"

    it "doesn't read the file when the file contents are specified", ->
      filePath = require.resolve("fixtures/shebang")
      filePathContents = fs.read(filePath)
      spyOn(fs, 'read').andCallThrough()
      expect(syntax.selectGrammar(filePath, filePathContents).name).toBe "Ruby"
      expect(fs.read).not.toHaveBeenCalled()

    it "allows the default grammar to be overridden for a path", ->
      path = '/foo/bar/file.js'
      expect(syntax.selectGrammar(path).name).not.toBe 'Ruby'
      syntax.setGrammarOverrideForPath(path, 'source.ruby')
      expect(syntax.selectGrammar(path).name).toBe 'Ruby'
      syntax.clearGrammarOverrideForPath(path)
      expect(syntax.selectGrammar(path).name).not.toBe 'Ruby'

  describe ".getProperty(scopeDescriptor)", ->
    it "returns the property with the most specific scope selector", ->
      syntax.addProperties(".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      syntax.addProperties(".source .string.quoted.double", foo: bar: baz: 22)
      syntax.addProperties(".source", foo: bar: baz: 11)
      syntax.addProperties(foo: bar: baz: 1)

      expect(syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
      expect(syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBe 22
      expect(syntax.getProperty([".source.js", ".variable.assignment.js"], "foo.bar.baz")).toBe 11
      expect(syntax.getProperty([".text"], "foo.bar.baz")).toBe 1

    it "favors the most recently added properties in the event of a specificity tie", ->
      syntax.addProperties(".source.coffee .string.quoted.single", foo: bar: baz: 42)
      syntax.addProperties(".source.coffee .string.quoted.double", foo: bar: baz: 22)

      expect(syntax.getProperty([".source.coffee", ".string.quoted.single"], "foo.bar.baz")).toBe 42
      expect(syntax.getProperty([".source.coffee", ".string.quoted.single.double"], "foo.bar.baz")).toBe 22
