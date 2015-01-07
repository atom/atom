# Tests the custom matchers defined in `./spec-helper.coffee`

describe "Custom matchers:", ->

  describe "The 'toBeInstanceOf' matcher", ->
    it "should test an object against its type", ->
      expect({}).toBeInstanceOf Object
      expect([]).toBeInstanceOf Array
      expect(->).toBeInstanceOf Function
      expect(/ab+/).toBeInstanceOf RegExp

      class BaseContrivedTestClass
      class ContrivedTestClass extends BaseContrivedTestClass
      expect(new ContrivedTestClass).toBeInstanceOf BaseContrivedTestClass

      expect(new Number(42)).toBeInstanceOf Number

    it "does NOT work with primitive values", ->
      expect("hello").not.toBeInstanceOf String
      expect(1).not.toBeInstanceOf Number


  describe "The 'toExistOnDisk' matcher", ->
  describe "The 'toHaveFocus' matcher", ->





  describe "The 'toShow' matcher", ->
