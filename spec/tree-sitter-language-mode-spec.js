const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

const dedent = require('dedent')
const TextBuffer = require('text-buffer')
const TextEditor = require('../src/text-editor')
const TreeSitterGrammar = require('../src/tree-sitter-grammar')
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode')

const cGrammarPath = require.resolve('language-c/grammars/tree-sitter-c.cson')
const pythonGrammarPath = require.resolve('language-python/grammars/tree-sitter-python.cson')
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

    it('can fold nodes that start and end with specified tokens', () => {
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
      expect(editor.isFoldableAtBufferRow(5)).toBe(false)

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

    it('can fold nodes of specified types', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          // Start the fold after the first child (the opening tag) and end it at the last child
          // (the closing tag).
          {
            type: 'jsx_element',
            start: {index: 0},
            end: {index: -1}
          },

          // End the fold at the *second* to last child of the self-closing tag: the `/`.
          {
            type: 'jsx_self_closing_element',
            start: {index: 1},
            end: {index: -2}
          }
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

        const element2 = <Element>…
        </Element>
      `)
    })

    it('can fold entire nodes when no start or end parameters are specified', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          // By default, for a node with no children, folds are started at the *end* of the first
          // line of a node, and ended at the *beginning* of the last line.
          {type: 'comment'}
        ]
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      buffer.setText(dedent `
        /**
         * Important
         */
        const x = 1 /*
          Also important
        */
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
        const x = 1 /*
          Also important
        */
      `)

      editor.foldBufferRow(3)
      expect(getDisplayText(editor)).toBe(dedent `
        /**… */
        const x = 1 /*…*/
      `)
    })

    it('tries each folding strategy for a given node in the order specified', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, cGrammarPath, {
        parser: 'tree-sitter-c',
        folds: [
          // If the #ifdef has an `#else` clause, then end the fold there.
          {
            type: ['preproc_ifdef', 'preproc_elif'],
            start: {index: 1},
            end: {type: 'preproc_else'}
          },
          {
            type: ['preproc_ifdef', 'preproc_elif'],
            start: {index: 1},
            end: {type: 'preproc_elif'}
          },

          // Otherwise, end the fold at the last child - the `#endif`.
          {
            type: 'preproc_ifdef',
            start: {index: 1},
            end: {index: -1}
          },

          // When folding an `#else` clause, the fold extends to the end of the clause.
          {
            type: 'preproc_else',
            start: {index: 0}
          }
        ]
      })

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))

      buffer.setText(dedent `
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32

        #include <windows.h>
        const char *path_separator = "\\";

        #elif defined MACOS

        #include <carbon.h>
        const char *path_separator = "/";

        #else

        #include <dirent.h>
        const char *path_separator = "/";

        #endif

        #endif
      `)

      editor.screenLineForScreenRow(0)

      editor.foldBufferRow(3)
      expect(getDisplayText(editor)).toBe(dedent `
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32…
        #elif defined MACOS

        #include <carbon.h>
        const char *path_separator = "/";

        #else

        #include <dirent.h>
        const char *path_separator = "/";

        #endif

        #endif
      `)

      editor.foldBufferRow(8)
      expect(getDisplayText(editor)).toBe(dedent `
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32…
        #elif defined MACOS…
        #else

        #include <dirent.h>
        const char *path_separator = "/";

        #endif

        #endif
      `)

      editor.foldBufferRow(0)
      expect(getDisplayText(editor)).toBe(dedent `
        #ifndef FOO_H_…
        #endif
      `)
    })

    describe('when folding a node that ends with a line break', () => {
      it('ends the fold at the end of the previous line', () => {
        const grammar = new TreeSitterGrammar(atom.grammars, pythonGrammarPath, {
          parser: 'tree-sitter-python',
          folds: [
            {
              type: 'function_definition',
              start: {type: ':'}
            }
          ]
        })

        buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))

        buffer.setText(dedent `
          def ab():
            print 'a'
            print 'b'

          def cd():
            print 'c'
            print 'd'
        `)

        editor.screenLineForScreenRow(0)

        editor.foldBufferRow(0)
        expect(getDisplayText(editor)).toBe(dedent `
          def ab():…

          def cd():
            print 'c'
            print 'd'
        `)
      })
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
