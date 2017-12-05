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

  describe('folding', () => {
    beforeEach(() => {
      editor.displayLayer.reset({foldCharacter: '…'})
    })

    it('can fold nodes that start and end with specified tokens and span multiple lines', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {
            start: {type: '{', index: 0},
            end: {type: '}', index: -1}
          },
          {
            start: {type: '(', index: 0},
            end: {type: ')', index: -1}
          }
        ]
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText(dedent `
        module.exports =
        class A {
          getB (c,
                d,
                e) {
            return this.f(g)
          }
        }
      `)

      editor.screenLineForScreenRow(0)

      expect(editor.isFoldableAtBufferRow(0)).toBe(false)
      expect(editor.isFoldableAtBufferRow(1)).toBe(true)
      expect(editor.isFoldableAtBufferRow(2)).toBe(true)
      expect(editor.isFoldableAtBufferRow(3)).toBe(false)
      expect(editor.isFoldableAtBufferRow(4)).toBe(true)

      editor.foldBufferRow(2)
      expect(getDisplayText(editor)).toBe(dedent `
        module.exports =
        class A {
          getB (…) {
            return this.f(g)
          }
        }
      `)

      editor.foldBufferRow(4)
      expect(getDisplayText(editor)).toBe(dedent `
        module.exports =
        class A {
          getB (…) {…}
        }
      `)
    })

    it('can fold nodes that start and end with specified tokens and span multiple lines', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {
            type: 'jsx_element',
            start: {index: 0, type: 'jsx_opening_element'},
            end: {index: -1, type: 'jsx_closing_element'}
          },
          {
            type: 'jsx_self_closing_element',
            start: {index: 1},
            end: {type: '/', index: -2}
          },
        ]
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText(dedent `
        const element1 = <Element
          className='submit'
          id='something' />

        const element2 = <Element>
          <span>hello</span>
          <span>world</span>
        </Element>
      `)

      editor.screenLineForScreenRow(0)

      expect(editor.isFoldableAtBufferRow(0)).toBe(true)
      expect(editor.isFoldableAtBufferRow(1)).toBe(false)
      expect(editor.isFoldableAtBufferRow(2)).toBe(false)
      expect(editor.isFoldableAtBufferRow(3)).toBe(false)
      expect(editor.isFoldableAtBufferRow(4)).toBe(true)
      expect(editor.isFoldableAtBufferRow(5)).toBe(false)

      editor.foldBufferRow(0)
      expect(getDisplayText(editor)).toBe(dedent `
        const element1 = <Element…/>

        const element2 = <Element>
          <span>hello</span>
          <span>world</span>
        </Element>
      `)

      editor.foldBufferRow(4)
      expect(getDisplayText(editor)).toBe(dedent `
        const element1 = <Element…/>

        const element2 = <Element>…</Element>
      `)
    })

    it('can fold specified types of multi-line nodes', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {type: 'template_string'},
          {type: 'comment'}
        ]
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText(dedent `
        /**
         * Important
         */
        const x = \`one
          two
          three\`
      `)

      editor.screenLineForScreenRow(0)

      expect(editor.isFoldableAtBufferRow(0)).toBe(true)
      expect(editor.isFoldableAtBufferRow(1)).toBe(false)
      expect(editor.isFoldableAtBufferRow(2)).toBe(false)
      expect(editor.isFoldableAtBufferRow(3)).toBe(true)
      expect(editor.isFoldableAtBufferRow(4)).toBe(false)

      editor.foldBufferRow(0)
      expect(getDisplayText(editor)).toBe(dedent `
        /**… */
        const x = \`one
          two
          three\`
      `)

      editor.foldBufferRow(3)
      expect(getDisplayText(editor)).toBe(dedent `
        /**… */
        const x = \`one…  three\`
      `)
    })
  })

  describe('TextEditor.selectLargerSyntaxNode and .selectSmallerSyntaxNode', () => {
    it('expands and contract the selection based on the syntax tree', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {'program': 'source'}
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText(dedent `
        function a (b, c, d) {
          eee.f()
          g()
        }
      `)

      editor.screenLineForScreenRow(0)

      editor.setCursorBufferPosition([1, 3])
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee.f')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee.f()')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('{\n  eee.f()\n  g()\n}')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('function a (b, c, d) {\n  eee.f()\n  g()\n}')

      editor.selectSmallerSyntaxNode()
      expect(editor.getSelectedText()).toBe('{\n  eee.f()\n  g()\n}')
      editor.selectSmallerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee.f()')
      editor.selectSmallerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee.f')
      editor.selectSmallerSyntaxNode()
      expect(editor.getSelectedText()).toBe('eee')
      editor.selectSmallerSyntaxNode()
      expect(editor.getSelectedBufferRange()).toEqual([[1, 3], [1, 3]])
    })
  })
})

function getDisplayText (editor) {
  return editor.displayLayer.getText()
}

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
