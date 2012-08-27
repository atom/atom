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

  describe ".getCaptureIndices(string, index)", ->
    it "returns match with nested capture groups organized into a tree", ->
      regex = new OnigRegExp("a((bc)d)e(f(g)(h))(?=ij)")
      tree = regex.getCaptureIndices("abcdefghij")

      expect(tree).toEqual [
        0, 0, 8
        1, 1, 4,
          2, 1, 3,
        3, 5, 8,
          4, 6, 7,
        5, 7, 8
      ]

    it "returns undefined if there was no match", ->
      regex = new OnigRegExp('x')
      expect(regex.getCaptureIndices('y')).toBeNull()

