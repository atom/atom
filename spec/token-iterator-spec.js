const TextBuffer = require('text-buffer')
const TokenizedBuffer = require('../src/tokenized-buffer')

describe('TokenIterator', () =>
  it('correctly terminates scopes at the beginning of the line (regression)', () => {
    const grammar = atom.grammars.createGrammar('test', {
      'scopeName': 'text.broken',
      'name': 'Broken grammar',
      'patterns': [
        {
          'begin': 'start',
          'end': '(?=end)',
          'name': 'blue.broken'
        },
        {
          'match': '.',
          'name': 'yellow.broken'
        }
      ]
    })

    const buffer = new TextBuffer({text: `\
start x
end x
x\
`})
    const tokenizedBuffer = new TokenizedBuffer({
      buffer,
      config: atom.config,
      grammarRegistry: atom.grammars,
      packageManager: atom.packages,
      assert: atom.assert
    })
    tokenizedBuffer.setGrammar(grammar)

    const tokenIterator = tokenizedBuffer.tokenizedLines[1].getTokenIterator()
    tokenIterator.next()

    expect(tokenIterator.getBufferStart()).toBe(0)
    expect(tokenIterator.getScopeEnds()).toEqual([])
    expect(tokenIterator.getScopeStarts()).toEqual(['text.broken', 'yellow.broken'])
  })
)
