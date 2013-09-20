textUtils = require '../src/text-utils'

describe 'text utilities', ->
  describe '.getCharacterCount(string)', ->
    it 'returns the number of full characters in the string', ->
      expect(textUtils.getCharacterCount('abc')).toBe 3
      expect(textUtils.getCharacterCount('a\uD835\uDF97b\uD835\uDF97c')).toBe 5
      expect(textUtils.getCharacterCount('\uD835\uDF97')).toBe 1
      expect(textUtils.getCharacterCount('\uD835')).toBe 1
      expect(textUtils.getCharacterCount('\uDF97')).toBe 1

  describe '.hasSurrogatePair(string)', ->
    it 'returns true when the string contains a surrogate pair', ->
      expect(textUtils.hasSurrogatePair('abc')).toBe false
      expect(textUtils.hasSurrogatePair('a\uD835\uDF97b\uD835\uDF97c')).toBe true
      expect(textUtils.hasSurrogatePair('\uD835\uDF97')).toBe true
      expect(textUtils.hasSurrogatePair('\uD835')).toBe false
      expect(textUtils.hasSurrogatePair('\uDF97')).toBe false

  describe '.isSurrogatePair(string, index)', ->
    it 'returns true when the index is the start of a high/low surrogate pair', ->
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 0)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 1)).toBe true
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 2)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 3)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 4)).toBe true
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 5)).toBe false
      expect(textUtils.isSurrogatePair('a\uD835\uDF97b\uD835\uDF97c', 6)).toBe false
      expect(textUtils.isSurrogatePair('\uD835')).toBe false
      expect(textUtils.isSurrogatePair('\uDF97')).toBe false
