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

  describe ".getCaptureTree(string, index)", ->
    it "returns match with nested capture groups organized into a tree", ->
      regex = new OnigRegExp("a((bc)d)e(f(g)(h))(?=ij)")
      tree = regex.getCaptureTree("abcdefghij")
      expect(tree).toEqual
        text: "abcdefgh"
        index: 0
        position: 0
        captures: [
          {
            text: "bcd"
            index: 1
            position: 1
            captures: [{ text: "bc", index: 2, position: 1 }]
          },
          {
            text: "fgh"
            index: 3
            position: 5
            captures: [
              { text: "g", index: 4, position: 6 }
              { text: "h", index: 5, position: 7 }
            ]
          }
        ]

    it "returns undefined if there was no match", ->
      regex = new OnigRegExp('x')
      expect(regex.getCaptureTree('y')).toBeUndefined()

