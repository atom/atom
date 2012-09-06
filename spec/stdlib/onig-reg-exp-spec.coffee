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

  describe "OnigRegExp.captureIndices(string, index, regexes)", ->
    it "returns index of matched regex and captureIndices for the regex", ->
      { index, captureIndices } = OnigRegExp.captureIndices("abcdefghij", 0, [new OnigRegExp("(\\d+)"), new OnigRegExp("a((bc)d)e(f(g)(h))(?=ij)")])

      expect(index).toBe(1)
      expect(captureIndices).toEqual [
        0, 0, 8
        1, 1, 4,
          2, 1, 3,
        3, 5, 8,
          4, 6, 7,
        5, 7, 8
      ]

    it "returns undefined if there was no match", ->
      { index, captureIndices } = OnigRegExp.captureIndices("abcdefghij", 0, [new OnigRegExp("(\\d+)"), new OnigRegExp("aaaa")])
      expect(index).toBeUndefined()

