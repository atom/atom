TextMateBundle = require 'text-mate-bundle'

describe "TextMateBundle", ->
  describe ".getPreferenceInScope(scope, preferenceName)", ->
    it "returns the preference by the given name in the given scope or undefined if there isn't one", ->
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'decreaseIndentPattern')).toBe '^\\s*(\\}|\\]|else|catch|finally)$'
      expect(TextMateBundle.getPreferenceInScope('source.coffee', 'shellVariables')).toBeDefined()

