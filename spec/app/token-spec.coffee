_ = require 'underscore'
Buffer = require 'buffer'
TokenizedBuffer = require 'tokenized-buffer'

describe "Token", ->
  [editSession, token] = []

  beforeEach ->
    tabText = '  '
    editSession = fixturesProject.buildEditSessionForPath('sample.js')
    { tokenizedBuffer } = editSession
    screenLine = tokenizedBuffer.lineForScreenRow(3)
    token = _.last(screenLine.tokens)

  afterEach ->
    editSession.destroy()

  describe ".getCssClassString()", ->
    it "returns a class for every scope prefix, replacing . characters in scope names with --", ->
      expect(token.getCssClassString()).toBe 'source source-js punctuation punctuation-terminator punctuation-terminator-statement punctuation-terminator-statement-js'
