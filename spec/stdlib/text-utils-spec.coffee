textUtils = require 'text-utils'

describe 'text utilities', ->
  describe '.getCharacterCount(string)', ->
    it 'returns the number of full characters in the string', ->
      expect(textUtils.getCharacterCount('abc')).toBe 3
      expect(textUtils.getCharacterCount('a\uD835\uDF97b\uD835\uDF97c')).toBe 5
      expect(textUtils.getCharacterCount('\uD835\uDF97')).toBe 1

  describe '.isSurrogatePair(string, index)', ->
    it 'returns true when the index is the start of a high/low surrogate pair', ->
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 0)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 1)).toBe true
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 2)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 3)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 4)).toBe true
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 5)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 6)).toBe false
