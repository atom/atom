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


  describe "the 'toHaveLength' matcher", ->
    it "should test that an array has the given length", ->
      expect([1,2,3]).toHaveLength 3
      expect({length: 5}).toHaveLength 5

    it "should fail a test if it does not the expected length", ->
      expect([]).not.toHaveLength 1

    it "should fail if the given value has no length property", ->
      expect(null).not.toHaveLength 1
      expect(1).not.toHaveLength 3

  describe "The 'toShow' matcher", ->
