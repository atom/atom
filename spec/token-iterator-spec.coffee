TextBuffer = require 'text-buffer'
TokenizedBuffer = require '../src/tokenized-buffer'

describe "TokenIterator", ->
  it "correctly terminates scopes at the beginning of the line (regression)", ->
    grammar = atom.grammars.createGrammar('test', {
      'scopeName': 'text.broken'
      'name': 'Broken grammar'
      'patterns': [
        {
          'begin': 'start'
          'end': '(?=end)'
          'name': 'blue.broken'
        }
        {
          'match': '.'
          'name': 'yellow.broken'
        }
      ]
    })

    buffer = new TextBuffer(text: """
      start x
      end x
      x
    """)
    tokenizedBuffer = new TokenizedBuffer({buffer})
    tokenizedBuffer.setGrammar(grammar)

    tokenIterator = tokenizedBuffer.tokenizedLineForRow(1).getTokenIterator()
    tokenIterator.next()

    expect(tokenIterator.getBufferStart()).toBe 0
    expect(tokenIterator.getScopeEnds()).toEqual []
    expect(tokenIterator.getScopeStarts()).toEqual ['text.broken', 'yellow.broken']
