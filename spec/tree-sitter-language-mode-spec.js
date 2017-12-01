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
    atom.config.set('core.useTreeSitterParsers', true)
  })

  describe('highlighting', () => {
    it('applies the most specific scope mapping to each token in the syntax tree', () => {
      grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
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
      expect(getTokens(editor).slice(0, 1)).toEqual([[
        {text: 'aa.', scopes: ['source']},
        {text: 'bbb', scopes: ['source', 'property']},
        {text: ' = ', scopes: ['source']},
        {text: 'cc', scopes: ['source', 'function']},
        {text: '(d.', scopes: ['source']},
        {text: 'eee', scopes: ['source', 'method']},
        {text: '());', scopes: ['source']}
      ]])
    })
  })
})

function getTokens (editor) {
  const result = []
  for (let row = 0, lastRow = editor.getLastScreenRow(); row <= lastRow; row++) {
    result.push(
      editor.tokensForScreenRow(row).map(({text, scopes}) => ({
        text,
        scopes: scopes.map(scope => scope
          .split(' ')
          .map(className => className.slice('syntax--'.length))
          .join(' '))
      }))
    )
  }
  return result
}
