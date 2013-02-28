OnigRegExp = require 'onig-reg-exp'

describe "OnigRegExp", ->
  describe ".search(string, index)", ->
    it "returns an array of the match and all capture groups", ->
      regex = OnigRegExp.create("\\w(\\d+)")
      result = regex.search("----a123----")
      expect(result).toEqual ["a123", "123"]
      expect(result.index).toBe 4
      expect(result.indices).toEqual [4, 5]

    it "returns null if it does not match", ->
      regex = OnigRegExp.create("\\w(\\d+)")
      result = regex.search("--------")
      expect(result).toBeNull()
