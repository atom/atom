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
    fit "returns match with nested capture groups organized into a tree", ->
      regex = new OnigRegExp("a((bc)d)e(f(g)(h))(?=ij)")
      tree = regex.getCaptureTree("abcdefghij")
      expect(tree).toEqual
        text: "abcdefgh"
        index: 0
        start: 0
        end: 8
        captures: [
          {
            index: 1
            start: 1
            end: 4
            captures: [{ index: 2, start: 1, end: 3 }]
          },
          {
            index: 3
            start: 5
            end: 8
            captures: [
              { index: 4, start: 6, end: 7 }
              { index: 5, start: 7, end: 8 }
            ]
          }
        ]

    it "returns undefined if there was no match", ->
      regex = new OnigRegExp('x')
      expect(regex.getCaptureTree('y')).toBeNull()

