textUtils = require '../src/text-utils'

describe 'text utilities', ->
  describe '.getCharacterCount(string)', ->
    it 'returns the number of full characters in the string', ->
      expect(textUtils.getCharacterCount('abc')).toBe 3
      expect(textUtils.getCharacterCount('a\uD835\uDF97b\uD835\uDF97c')).toBe 5
      expect(textUtils.getCharacterCount('\uD835\uDF97')).toBe 1
      expect(textUtils.getCharacterCount('\u2714\uFE0E')).toBe 1
      expect(textUtils.getCharacterCount('\uD835')).toBe 1
      expect(textUtils.getCharacterCount('\uDF97')).toBe 1
      expect(textUtils.getCharacterCount('\uFE0E')).toBe 1
      expect(textUtils.getCharacterCount('\uFE0E\uFE0E')).toBe 2

  describe '.hasPairedCharacter(string)', ->
    it 'returns true when the string contains a surrogate pair or variation sequence', ->
      expect(textUtils.hasPairedCharacter('abc')).toBe false
      expect(textUtils.hasPairedCharacter('a\uD835\uDF97b\uD835\uDF97c')).toBe true
      expect(textUtils.hasPairedCharacter('\uD835\uDF97')).toBe true
      expect(textUtils.hasPairedCharacter('\u2714\uFE0E')).toBe true
      expect(textUtils.hasPairedCharacter('\uD835')).toBe false
      expect(textUtils.hasPairedCharacter('\uDF97')).toBe false
      expect(textUtils.hasPairedCharacter('\uFE0E')).toBe false
      expect(textUtils.hasPairedCharacter('\uFE0E\uFE0E')).toBe false

  describe '.isPairedCharacter(string, index)', ->
    it 'returns true when the index is the start of a high/low surrogate pair or variation sequence', ->
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 0)).toBe false
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 1)).toBe true
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 2)).toBe false
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 3)).toBe false
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 4)).toBe true
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 5)).toBe false
      expect(textUtils.isPairedCharacter('a\uD835\uDF97b\uD835\uDF97c', 6)).toBe false
      expect(textUtils.isPairedCharacter('a\u2714\uFE0E', 0)).toBe false
      expect(textUtils.isPairedCharacter('a\u2714\uFE0E', 1)).toBe true
      expect(textUtils.isPairedCharacter('a\u2714\uFE0E', 2)).toBe false
      expect(textUtils.isPairedCharacter('a\u2714\uFE0E', 3)).toBe false
      expect(textUtils.isPairedCharacter('\uD835')).toBe false
      expect(textUtils.isPairedCharacter('\uDF97')).toBe false
      expect(textUtils.isPairedCharacter('\uFE0E')).toBe false
      expect(textUtils.isPairedCharacter('\uFE0E')).toBe false
      expect(textUtils.isPairedCharacter('\uFE0E\uFE0E')).toBe false
