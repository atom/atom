_ = require 'underscore'
Token = require 'token'
Buffer = require 'buffer'
TokenizedBuffer = require 'tokenized-buffer'

describe "Token", ->
  [editSession, token] = []

  beforeEach ->
    editSession = fixturesProject.buildEditSessionForPath('sample.js', { tabLength: 2 })
    { tokenizedBuffer } = editSession
    screenLine = tokenizedBuffer.lineForScreenRow(3)
    token = _.last(screenLine.tokens)

  afterEach ->
    editSession.destroy()

  describe ".breakOutWhitespaceCharacters(tabLength, showInvisbles)", ->
    describe "when showInvisbles is false", ->
      it "replaces spaces and tabs with their own tokens", ->
        value = " spaces   tabs\t\t\t  "
        scopes = ["whatever"]
        isAtomic = false
        bufferDelta = value.length
        token = new Token({value, scopes, isAtomic, bufferDelta})
        tokens = token.breakOutWhitespaceCharacters(4, false)

        expect(tokens.length).toBe(8)
        expect(tokens[0].value).toBe(" ")
        expect(tokens[0].scopes).not.toContain("invisible")
        expect(tokens[1].value).toBe("spaces")
        expect(tokens[1].scopes).not.toContain("invisible")
        expect(tokens[2].value).toBe("   ")
        expect(tokens[3].value).toBe("tabs")
        expect(tokens[4].value).toBe("    ")
        expect(tokens[4].scopes).not.toContain("invisible")
        expect(tokens[5].value).toBe("    ")
        expect(tokens[6].value).toBe("    ")
        expect(tokens[7].value).toBe("  ")

    describe "when showInvisbles is true", ->
      it "replaces spaces and tabs with their own tokens", ->
        value = " spaces   tabs\t\t\t  "
        scopes = ["whatever"]
        isAtomic = false
        bufferDelta = value.length
        token = new Token({value, scopes, isAtomic, bufferDelta})
        tokens = token.breakOutWhitespaceCharacters(4, true)

        expect(tokens.length).toBe(8)
        expect(tokens[0].value).toBe("•")
        expect(tokens[0].scopes).toContain("invisible")
        expect(tokens[1].value).toBe("spaces")
        expect(tokens[1].scopes).not.toContain("invisible")
        expect(tokens[2].value).toBe("•••")
        expect(tokens[3].value).toBe("tabs")
        expect(tokens[4].value).toBe("▸   ")
        expect(tokens[4].scopes).toContain("invisible")
        expect(tokens[5].value).toBe("▸   ")
        expect(tokens[6].value).toBe("▸   ")
        expect(tokens[7].value).toBe("••")
