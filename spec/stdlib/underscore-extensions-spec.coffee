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

  describe "camelize(string)", ->
    it "converts `string` to camel case", ->
      expect(_.camelize("corey_dale_johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("corey-dale-johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("corey_dale-johnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("coreyDaleJohnson")).toBe "coreyDaleJohnson"
      expect(_.camelize("CoreyDaleJohnson")).toBe "CoreyDaleJohnson"

  describe "dasherize(string)", ->
    it "converts `string` to use dashes", ->
      expect(_.dasherize("corey_dale_johnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("coreyDaleJohnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("CoreyDaleJohnson")).toBe "corey-dale-johnson"
      expect(_.dasherize("corey-dale-johnson")).toBe "corey-dale-johnson"

  describe "underscore(string)", ->
    it "converts `string` to use underscores", ->
      expect(_.underscore("corey-dale-johnson")).toBe "corey_dale_johnson"
      expect(_.underscore("coreyDaleJohnson")).toBe "corey_dale_johnson"
      expect(_.underscore("CoreyDaleJohnson")).toBe "corey_dale_johnson"
      expect(_.underscore("corey_dale_johnson")).toBe "corey_dale_johnson"


