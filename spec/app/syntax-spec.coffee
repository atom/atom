fs = require 'fs-utils'

describe "the `syntax` global", ->
  describe ".grammarForFilePath(filePath)", ->
    it "uses the filePath's extension to load the correct grammar", ->
      expect(syntax.grammarForFilePath("file.js").name).toBe "JavaScript"

    it "uses the filePath's base name if there is no extension", ->
      expect(syntax.grammarForFilePath("Rakefile").name).toBe "Ruby"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("fixtures/shebang")
      expect(syntax.grammarForFilePath(filePath).name).toBe "Ruby"

    it "uses the number of newlines in the first line regex to determine the number of lines to test against", ->
      fileContent = "first-line\n<html>"
      expect(syntax.grammarForFilePath("dummy.coffee", fileContent).name).toBe "CoffeeScript"

      fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
      expect(syntax.grammarForFilePath("grammar.tmLanguage", fileContent).name).toBe "Plain Text"

      fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      expect(syntax.grammarForFilePath("grammar.tmLanguage", fileContent).name).toBe "Property List (XML)"

    it "doesn't read the file when the file contents are specified", ->
      filePath = require.resolve("fixtures/shebang")
      filePathContents = fs.read(filePath)
      spyOn(fs, 'read').andCallThrough()
      expect(syntax.grammarForFilePath(filePath, filePathContents).name).toBe "Ruby"
      expect(fs.read).not.toHaveBeenCalled()

    it "uses the grammar's fileType as a suffix of the full filePath if the grammar cannot be determined by shebang line", ->
      expect(syntax.grammarForFilePath("/tmp/.git/config").name).toBe "Git Config"

    it "uses plain text if no grammar can be found", ->
      expect(syntax.grammarForFilePath("this-is-not-a-real-file").name).toBe "Plain Text"

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
