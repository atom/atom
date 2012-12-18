fs = require('fs')
TextMateBundle = require 'text-mate-bundle'

describe "TextMateBundle", ->
  describe ".getPreferenceInScope(scope, preferenceName)", ->
    it "returns the preference by the given name in the given scope or undefined if there isn't one", ->
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'decreaseIndentPattern')).toBe '^\\s*(\\}|\\]|else|catch|finally)$'
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'shellVariables')).toBeDefined()

    it "returns the preference by the given name in the given scope for a scope registered via a comma-separated list of scopes", ->
      expect(TextMateBundle.getPreferenceInScope('source.objc++', 'shellVariables')).toBeDefined()

  describe ".getPreferencesByScopeSelector()", ->
    it "logs warning, but does not raise errors if a preference can't be parsed", ->
      bundlePath = fs.join(require.resolve('fixtures'), "test.tmbundle")
      spyOn(console, 'warn')
      bundle = new TextMateBundle(bundlePath)
      expect(-> bundle.getPreferencesByScopeSelector()).not.toThrow()
      expect(console.warn).toHaveBeenCalled()

  describe ".constructor(bundlePath)", ->
    it "logs warning, but does not raise errors if a grammar can't be parsed", ->
      bundlePath = fs.join(require.resolve('fixtures'), "test.tmbundle")
      spyOn(console, 'warn')
      expect(-> new TextMateBundle(bundlePath)).not.toThrow()
      expect(console.warn).toHaveBeenCalled()

  describe ".grammarForFilePath(filePath)", ->
    it "uses the filePath's extension to load the correct grammar", ->
      expect(TextMateBundle.grammarForFilePath("file.js").name).toBe "JavaScript"

    it "uses the filePath's base name if there is no extension", ->
      expect(TextMateBundle.grammarForFilePath("Rakefile").name).toBe "Ruby"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("fixtures/shebang")
      expect(TextMateBundle.grammarForFilePath(filePath).name).toBe "Ruby"

    it "uses plain text if no grammar can be found", ->
      filePath = require.resolve("this-is-not-a-real-file")
      expect(TextMateBundle.grammarForFilePath(filePath).name).toBe "Plain Text"
