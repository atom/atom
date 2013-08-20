_ = require 'underscore'

describe "underscore extensions", ->
  describe "_.adviseBefore", ->
    [object, calls] = []

    beforeEach ->
      calls = []
      object = {
        method: (args...) ->
          calls.push(["original", this, args])
      }

    it "calls the given function before the advised method", ->
      _.adviseBefore object, 'method', (args...) -> calls.push(["advice", this, args])
      object.method(1, 2, 3)
      expect(calls).toEqual [['advice', object, [1, 2, 3]], ['original', object, [1, 2, 3]]]

    it "cancels the original method's invocation if the advice returns true", ->
      _.adviseBefore object, 'method', -> false
      object.method(1, 2, 3)
      expect(calls).toEqual []

  describe "_.endsWith", ->
    it "returns whether the given string ends with the given suffix", ->
      expect(_.endsWith("test.txt", ".txt")).toBeTruthy()
      expect(_.endsWith("test.txt", "txt")).toBeTruthy()
      expect(_.endsWith("test.txt", "test.txt")).toBeTruthy()
      expect(_.endsWith("test.txt", "")).toBeTruthy()
      expect(_.endsWith("test.txt", ".txt2")).toBeFalsy()
      expect(_.endsWith("test.txt", ".tx")).toBeFalsy()
      expect(_.endsWith("test.txt", "test")).toBeFalsy()

  describe "_.camelize(string)", ->
    it "converts `string` to camel case", ->
      expect(_.camelize("corey_dale_johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("corey-dale-johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("corey_dale-johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("coreyDaleJohnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("CoreyDaleJohnson")).toBe "CoreyDaleJohnson"

  describe "_.dasherize(string)", ->
    it "converts `string` to use dashes", ->
      expect(_.dasherize("corey_dale_johnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("coreyDaleJohnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("CoreyDaleJohnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("corey-dale-johnson")).toBe "corey-dale-johnson"

  describe "_.underscore(string)", ->
    it "converts `string` to use underscores", ->
      expect(_.underscore("corey-dale-johnson")).toBe "corey_dale_johnson"
      expect(_.underscore("coreyDaleJohnson")).toBe "corey_dale_johnson"
      expect(_.underscore("CoreyDaleJohnson")).toBe "corey_dale_johnson"
      expect(_.underscore("corey_dale_johnson")).toBe "corey_dale_johnson"

  describe "spliceWithArray(originalArray, start, length, insertedArray, chunkSize)", ->
    describe "when the inserted array is smaller than the chunk size", ->
      it "splices the array in place", ->
        array = ['a', 'b', 'c']
        _.spliceWithArray(array, 1, 1, ['v', 'w', 'x', 'y', 'z'], 100)
        expect(array).toEqual ['a', 'v', 'w', 'x', 'y', 'z', 'c']

    describe "when the inserted array is larger than the chunk size", ->
      it "splices the array in place one chunk at a time (to avoid stack overflows)", ->
        array = ['a', 'b', 'c']
        _.spliceWithArray(array, 1, 1, ['v', 'w', 'x', 'y', 'z'], 2)
        expect(array).toEqual ['a', 'v', 'w', 'x', 'y', 'z', 'c']

  describe "_.humanizeEventName(eventName)", ->
    describe "when no namespace exists", ->
      it "undasherizes and capitalizes the event name", ->
        expect(_.humanizeEventName('nonamespace')).toBe 'Nonamespace'
        expect(_.humanizeEventName('no-name-space')).toBe 'No Name Space'

    describe "when a namespaces exists", ->
      it "space separates the undasherized/capitalized versions of the namespace and event name", ->
        expect(_.humanizeEventName('space:final-frontier')).toBe 'Space: Final Frontier'
        expect(_.humanizeEventName('star-trek:the-next-generation')).toBe 'Star Trek: The Next Generation'

  describe "_.deepExtend(objects...)", ->
    it "copies all key/values from each object into a new object", ->
      first =
        things:
          string: "oh"
          boolean: false
          anotherArray: ['a', 'b', 'c']
          object:
            first: 1
            second: 2

      second =
        things:
          string: "cool"
          array: [1,2,3]
          anotherArray: ['aa', 'bb', 'cc']
          object:
            first: 1

      result = _.deepExtend(first, second)

      expect(result).toEqual
        things:
          string: "oh"
          boolean: false
          array: [1,2,3]
          anotherArray: ['a', 'b', 'c']
          object:
            first: 1
            second: 2

  describe "_.isSubset(potentialSubset, potentialSuperset)", ->
    it "returns whether the first argument is a subset of the second", ->
      expect(_.isSubset([1, 2], [1, 2])).toBeTruthy()
      expect(_.isSubset([1, 2], [1, 2, 3])).toBeTruthy()
      expect(_.isSubset([], [1])).toBeTruthy()
      expect(_.isSubset([], [])).toBeTruthy()
      expect(_.isSubset([1, 2], [2, 3])).toBeFalsy()
