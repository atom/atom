_ = require 'underscore'
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
