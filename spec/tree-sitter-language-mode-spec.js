const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

const dedent = require('dedent')
const TextBuffer = require('text-buffer')
const TextEditor = require('../src/text-editor')
const TreeSitterGrammar = require('../src/tree-sitter-grammar')
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode')

const jsGrammarPath = require.resolve('language-javascript/grammars/tree-sitter-javascript.cson')

describe('TreeSitterLanguageMode', () => {
  let editor, buffer

  beforeEach(async () => {
    editor = await atom.workspace.open('')
    buffer = editor.getBuffer()
  })

  describe('highlighting', () => {
    it('applies the most specific scope mapping to each node in the syntax tree', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'program': 'source',
          'call_expression > identifier': 'function',
          'property_identifier': 'property',
          'call_expression > member_expression > property_identifier': 'method'
        }
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText('aa.bbb = cc(d.eee());')
      expectTokensToEqual(editor, [
        {text: 'aa.', scopes: ['source']},
        {text: 'bbb', scopes: ['source', 'property']},
        {text: ' = ', scopes: ['source']},
        {text: 'cc', scopes: ['source', 'function']},
        {text: '(d.', scopes: ['source']},
        {text: 'eee', scopes: ['source', 'method']},
        {text: '());', scopes: ['source']}
      ])
    })

    it('can start or end multiple scopes at the same position', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'program': 'source',
          'call_expression': 'call',
          'member_expression': 'member',
          'identifier': 'variable',
          '"("': 'open-paren',
          '")"': 'close-paren',
        }
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText('a = bb.ccc();')
      expectTokensToEqual(editor, [
        {text: 'a', scopes: ['source', 'variable']},
        {text: ' = ', scopes: ['source']},
        {text: 'bb', scopes: ['source', 'call', 'member', 'variable']},
        {text: '.ccc', scopes: ['source', 'call', 'member']},
        {text: '(', scopes: ['source', 'call', 'open-paren']},
        {text: ')', scopes: ['source', 'call', 'close-paren']},
        {text: ';', scopes: ['source']}
      ])
    })
  })
})

function expectTokensToEqual (editor, expectedTokens) {
  const tokens = []
  for (let row = 0, lastRow = editor.getLastScreenRow(); row <= lastRow; row++) {
    tokens.push(
      ...editor.tokensForScreenRow(row).map(({text, scopes}) => ({
        text,
        scopes: scopes.map(scope => scope
          .split(' ')
          .map(className => className.slice('syntax--'.length))
          .join(' '))
      }))
    )
  }

  expect(tokens.length).toEqual(expectedTokens.length)
  for (let i = 0; i < tokens.length; i++) {
    expect(tokens[i]).toEqual(expectedTokens[i], `Token ${i}`)
  }
}
