{OnigRegExp} = require 'oniguruma'

describe "OnigRegExp", ->
  describe ".search(string, index)", ->
    it "returns an array of the match and all capture groups", ->
      regex = new OnigRegExp("\\w(\\d+)")
      result = regex.search("----a123----")
      expect(result).toEqual ["a123", "123"]
      expect(result.index).toBe 4
      expect(result.indices).toEqual [4, 5]

    it "returns null if it does not match", ->
      regex = new OnigRegExp("\\w(\\d+)")
      result = regex.search("--------")
      expect(result).toBeNull()
