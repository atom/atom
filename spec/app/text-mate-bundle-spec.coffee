fs = require('fs')
TextMateBundle = require 'text-mate-bundle'

describe "TextMateBundle", ->
  describe ".getPreferenceInScope(scope, preferenceName)", ->
    it "returns the preference by the given name in the given scope or undefined if there isn't one", ->
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'decreaseIndentPattern')).toBe '^\\s*(\\}|\\]|else|catch|finally)$'
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'shellVariables')).toBeDefined()

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
