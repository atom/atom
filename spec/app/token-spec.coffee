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
