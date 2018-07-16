const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

const dedent = require('dedent')
const TextBuffer = require('text-buffer')
const {Point} = TextBuffer
const TextEditor = require('../src/text-editor')
const TreeSitterGrammar = require('../src/tree-sitter-grammar')
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode')

const cGrammarPath = require.resolve('language-c/grammars/tree-sitter-c.cson')
const pythonGrammarPath = require.resolve('language-python/grammars/tree-sitter-python.cson')
const jsGrammarPath = require.resolve('language-javascript/grammars/tree-sitter-javascript.cson')
const htmlGrammarPath = require.resolve('language-html/grammars/tree-sitter-html.cson')
const ejsGrammarPath = require.resolve('language-html/grammars/tree-sitter-ejs.cson')

describe('TreeSitterLanguageMode', () => {
  let editor, buffer

  beforeEach(async () => {
    editor = await atom.workspace.open('')
    buffer = editor.getBuffer()
    editor.displayLayer.reset({foldCharacter: '…'})
  })

  describe('highlighting', () => {
    it('applies the most specific scope mapping to each node in the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'program': 'source',
          'call_expression > identifier': 'function',
          'property_identifier': 'property',
          'call_expression > member_expression > property_identifier': 'method'
        }
      })

      buffer.setText('aa.bbb = cc(d.eee());')

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      expectTokensToEqual(editor, [[
        {text: 'aa.', scopes: ['source']},
        {text: 'bbb', scopes: ['source', 'property']},
        {text: ' = ', scopes: ['source']},
        {text: 'cc', scopes: ['source', 'function']},
        {text: '(d.', scopes: ['source']},
        {text: 'eee', scopes: ['source', 'method']},
        {text: '());', scopes: ['source']}
      ]])
    })

    it('can start or end multiple scopes at the same position', async () => {
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

      buffer.setText('a = bb.ccc();')

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      expectTokensToEqual(editor, [[
        {text: 'a', scopes: ['source', 'variable']},
        {text: ' = ', scopes: ['source']},
        {text: 'bb', scopes: ['source', 'call', 'member', 'variable']},
        {text: '.ccc', scopes: ['source', 'call', 'member']},
        {text: '(', scopes: ['source', 'call', 'open-paren']},
        {text: ')', scopes: ['source', 'call', 'close-paren']},
        {text: ';', scopes: ['source']}
      ]])
    })

    it('can resume highlighting on a line that starts with whitespace', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'call_expression > member_expression > property_identifier': 'function',
          'property_identifier': 'member',
          'identifier': 'variable'
        }
      })

      buffer.setText('a\n  .b();')

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      expectTokensToEqual(editor, [
        [
          {text: 'a', scopes: ['variable']},
        ],
        [
          {text: '  ', scopes: ['leading-whitespace']},
          {text: '.', scopes: []},
          {text: 'b', scopes: ['function']},
          {text: '();', scopes: []}
        ]
      ])
    })

    it('correctly skips over tokens with zero size', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-c',
        scopes: {
          'primitive_type': 'type',
          'identifier': 'variable',
        }
      })

      buffer.setText('int main() {\n  int a\n  int b;\n}');

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      expect(
        languageMode.tree.rootNode.descendantForPosition(Point(1, 2), Point(1, 6)).toString()
      ).toBe('(declaration (primitive_type) (identifier) (MISSING))')

      expectTokensToEqual(editor, [
        [
          {text: 'int', scopes: ['type']},
          {text: ' ', scopes: []},
          {text: 'main', scopes: ['variable']},
          {text: '() {', scopes: []}
        ],
        [
          {text: '  ', scopes: ['leading-whitespace']},
          {text: 'int', scopes: ['type']},
          {text: ' ', scopes: []},
          {text: 'a', scopes: ['variable']}
        ],
        [
          {text: '  ', scopes: ['leading-whitespace']},
          {text: 'int', scopes: ['type']},
          {text: ' ', scopes: []},
          {text: 'b', scopes: ['variable']},
          {text: ';', scopes: []}
        ],
        [
          {text: '}', scopes: []}
        ]
      ])
    })

    it('updates lines\' highlighting when they are affected by distant changes', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'call_expression > identifier': 'function',
          'property_identifier': 'member'
        }
      })

      buffer.setText('a(\nb,\nc\n')

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      // missing closing paren
      expectTokensToEqual(editor, [
        [{text: 'a(', scopes: []}],
        [{text: 'b,', scopes: []}],
        [{text: 'c', scopes: []}],
        [{text: '', scopes: []}]
      ])

      buffer.append(')')
      await nextHighlightingUpdate(languageMode)
      expectTokensToEqual(editor, [
        [
          {text: 'a', scopes: ['function']},
          {text: '(', scopes: []}
        ],
        [{text: 'b,', scopes: []}],
        [{text: 'c', scopes: []}],
        [{text: ')', scopes: []}]
      ])
    })

    it('handles edits after tokens that end between CR and LF characters (regression)', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'comment': 'comment',
          'string': 'string',
          'property_identifier': 'property',
        }
      })

      buffer.setText([
        '// abc',
        '',
        'a("b").c'
      ].join('\r\n'))

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)

      await nextHighlightingUpdate(languageMode)
      expectTokensToEqual(editor, [
        [{text: '// abc', scopes: ['comment']}],
        [{text: '', scopes: []}],
        [
          {text: 'a(', scopes: []},
          {text: '"b"', scopes: ['string']},
          {text: ').', scopes: []},
          {text: 'c', scopes: ['property']}
        ]
      ])

      buffer.insert([2, 0], '  ')
      await nextHighlightingUpdate(languageMode)
      expectTokensToEqual(editor, [
        [{text: '// abc', scopes: ['comment']}],
        [{text: '', scopes: []}],
        [
          {text: '  ', scopes: ['leading-whitespace']},
          {text: 'a(', scopes: []},
          {text: '"b"', scopes: ['string']},
          {text: ').', scopes: []},
          {text: 'c', scopes: ['property']}
        ]
      ])
    })

    it('handles multi-line nodes with children on different lines (regression)', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'template_string': 'string',
          '"${"': 'interpolation',
          '"}"': 'interpolation'
        }
      });

      buffer.setText('`\na${1}\nb${2}\n`;')

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      expectTokensToEqual(editor, [
        [
          {text: '`', scopes: ['string']}
        ], [
          {text: 'a', scopes: ['string']},
          {text: '${', scopes: ['string', 'interpolation']},
          {text: '1', scopes: ['string']},
          {text: '}', scopes: ['string', 'interpolation']}
        ], [
          {text: 'b', scopes: ['string']},
          {text: '${', scopes: ['string', 'interpolation']},
          {text: '2', scopes: ['string']},
          {text: '}', scopes: ['string', 'interpolation']}
        ],
        [
          {text: '`', scopes: ['string']},
          {text: ';', scopes: []}
        ]
      ])
    })

    it('handles folds inside of highlighted tokens', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'comment': 'comment',
          'call_expression > identifier': 'function',
        }
      })

      buffer.setText(dedent `
        /*
         * Hello
         */

        hello();
      `)

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      editor.foldBufferRange([[0, 2], [2, 0]])

      expectTokensToEqual(editor, [
        [
          {text: '/*', scopes: ['comment']},
          {text: '…', scopes: ['fold-marker']},
          {text: ' */', scopes: ['comment']}
        ],
        [
          {text: '', scopes: []}
        ],
        [
          {text: 'hello', scopes: ['function']},
          {text: '();', scopes: []},
        ]
      ])
    })

    describe('when the buffer changes during a parse', () => {
      it('immediately parses again when the current parse completes', async () => {
        const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          parser: 'tree-sitter-javascript',
          scopes: {
            'identifier': 'variable',
            'call_expression > identifier': 'function',
            'new_expression > call_expression > identifier': 'constructor'
          }
        })

        buffer.setText('abc;');

        const languageMode = new TreeSitterLanguageMode({buffer, grammar})
        buffer.setLanguageMode(languageMode)
        await nextHighlightingUpdate(languageMode)
        await new Promise(process.nextTick)

        expectTokensToEqual(editor, [
          [
            {text: 'abc', scopes: ['variable']},
            {text: ';', scopes: []}
          ],
        ])

        buffer.setTextInRange([[0, 3], [0, 3]], '()');
        expectTokensToEqual(editor, [
          [
            {text: 'abc()', scopes: ['variable']},
            {text: ';', scopes: []}
          ],
        ])

        buffer.setTextInRange([[0, 0], [0, 0]], 'new ');
        expectTokensToEqual(editor, [
          [
            {text: 'new ', scopes: []},
            {text: 'abc()', scopes: ['variable']},
            {text: ';', scopes: []}
          ],
        ])

        await nextHighlightingUpdate(languageMode)
        expectTokensToEqual(editor, [
          [
            {text: 'new ', scopes: []},
            {text: 'abc', scopes: ['function']},
            {text: '();', scopes: []}
          ],
        ])

        await nextHighlightingUpdate(languageMode)
        expectTokensToEqual(editor, [
          [
            {text: 'new ', scopes: []},
            {text: 'abc', scopes: ['constructor']},
            {text: '();', scopes: []}
          ],
        ])
      })
    })

    describe('injectionPoints and injectionPatterns', () => {
      let jsGrammar, htmlGrammar

      beforeEach(() => {
        jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          id: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {
            'property_identifier': 'property',
            'call_expression > identifier': 'function',
            'template_string': 'string',
            'template_substitution > "${"': 'interpolation',
            'template_substitution > "}"': 'interpolation'
          },
          injectionRegExp: 'javascript',
          injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
        })

        htmlGrammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
          id: 'html',
          parser: 'tree-sitter-html',
          scopes: {
            fragment: 'html',
            tag_name: 'tag',
            attribute_name: 'attr'
          },
          injectionRegExp: 'html',
          injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
        })
      })

      it('highlights code inside of injection points', async () => {
        atom.grammars.addGrammar(jsGrammar)
        atom.grammars.addGrammar(htmlGrammar)
        buffer.setText('node.innerHTML = html `\na ${b}<img src="d">\n`;')

        const languageMode = new TreeSitterLanguageMode({buffer, grammar: jsGrammar, grammars: atom.grammars})
        buffer.setLanguageMode(languageMode)
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)

        expectTokensToEqual(editor, [
          [
            {text: 'node.', scopes: []},
            {text: 'innerHTML', scopes: ['property']},
            {text: ' = ', scopes: []},
            {text: 'html', scopes: ['function']},
            {text: ' ', scopes: []},
            {text: '`', scopes: ['string']},
            {text: '', scopes: ['string', 'html']}
          ], [
            {text: 'a ', scopes: ['string', 'html']},
            {text: '${', scopes: ['string', 'html', 'interpolation']},
            {text: 'b', scopes: ['string', 'html']},
            {text: '}', scopes: ['string', 'html', 'interpolation']},
            {text: '<', scopes: ['string', 'html']},
            {text: 'img', scopes: ['string', 'html', 'tag']},
            {text: ' ', scopes: ['string', 'html']},
            {text: 'src', scopes: ['string', 'html', 'attr']},
            {text: '="d">', scopes: ['string', 'html']}
          ], [
            {text: '`', scopes: ['string']},
            {text: ';', scopes: []},
          ],
        ])

        const range = buffer.findSync('html')
        buffer.setTextInRange(range, 'xml')
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)

        expectTokensToEqual(editor, [
          [
            {text: 'node.', scopes: []},
            {text: 'innerHTML', scopes: ['property']},
            {text: ' = ', scopes: []},
            {text: 'xml', scopes: ['function']},
            {text: ' ', scopes: []},
            {text: '`', scopes: ['string']}
          ], [
            {text: 'a ', scopes: ['string']},
            {text: '${', scopes: ['string', 'interpolation']},
            {text: 'b', scopes: ['string']},
            {text: '}', scopes: ['string', 'interpolation']},
            {text: '<img src="d">', scopes: ['string']},
          ], [
            {text: '`', scopes: ['string']},
            {text: ';', scopes: []},
          ],
        ])
      })

      it('highlights the content after injections', async () => {
        atom.grammars.addGrammar(jsGrammar)
        atom.grammars.addGrammar(htmlGrammar)
        buffer.setText('<script>\nhello();\n</script>\n<div>\n</div>')

        const languageMode = new TreeSitterLanguageMode({buffer, grammar: htmlGrammar, grammars: atom.grammars})
        buffer.setLanguageMode(languageMode)
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)

        expectTokensToEqual(editor, [
          [
            {text: '<', scopes: ['html']},
            {text: 'script', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']},
          ],
          [
            {text: 'hello', scopes: ['html', 'function']},
            {text: '();', scopes: ['html']},
          ],
          [
            {text: '</', scopes: ['html']},
            {text: 'script', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']},
          ],
          [
            {text: '<', scopes: ['html']},
            {text: 'div', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']},
          ],
          [
            {text: '</', scopes: ['html']},
            {text: 'div', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']},
          ]
        ])
      })

      it('updates buffers highlighting when a grammar with injectionRegExp is added', async () => {
        atom.grammars.addGrammar(jsGrammar)

        buffer.setText('node.innerHTML = html `\na ${b}<img src="d">\n`;')
        const languageMode = new TreeSitterLanguageMode({buffer, grammar: jsGrammar, grammars: atom.grammars})
        buffer.setLanguageMode(languageMode)

        await nextHighlightingUpdate(languageMode)
        expectTokensToEqual(editor, [
          [
            {text: 'node.', scopes: []},
            {text: 'innerHTML', scopes: ['property']},
            {text: ' = ', scopes: []},
            {text: 'html', scopes: ['function']},
            {text: ' ', scopes: []},
            {text: '`', scopes: ['string']}
          ], [
            {text: 'a ', scopes: ['string']},
            {text: '${', scopes: ['string', 'interpolation']},
            {text: 'b', scopes: ['string']},
            {text: '}', scopes: ['string', 'interpolation']},
            {text: '<img src="d">', scopes: ['string']},
          ], [
            {text: '`', scopes: ['string']},
            {text: ';', scopes: []},
          ],
        ])

        atom.grammars.addGrammar(htmlGrammar)
        await nextHighlightingUpdate(languageMode)
        expectTokensToEqual(editor, [
          [
            {text: 'node.', scopes: []},
            {text: 'innerHTML', scopes: ['property']},
            {text: ' = ', scopes: []},
            {text: 'html', scopes: ['function']},
            {text: ' ', scopes: []},
            {text: '`', scopes: ['string']},
            {text: '', scopes: ['string', 'html']}
          ], [
            {text: 'a ', scopes: ['string', 'html']},
            {text: '${', scopes: ['string', 'html', 'interpolation']},
            {text: 'b', scopes: ['string', 'html']},
            {text: '}', scopes: ['string', 'html', 'interpolation']},
            {text: '<', scopes: ['string', 'html']},
            {text: 'img', scopes: ['string', 'html', 'tag']},
            {text: ' ', scopes: ['string', 'html']},
            {text: 'src', scopes: ['string', 'html', 'attr']},
            {text: '="d">', scopes: ['string', 'html']}
          ], [
            {text: '`', scopes: ['string']},
            {text: ';', scopes: []},
          ],
        ])
      })

      it('handles injections that intersect', async () => {
        const ejsGrammar = new TreeSitterGrammar(atom.grammars, ejsGrammarPath, {
          id: 'ejs',
          parser: 'tree-sitter-embedded-template',
          scopes: {
            '"<%="': 'directive',
            '"%>"': 'directive',
          },
          injectionPoints: [
            {
              type: 'template',
              language (node) { return 'javascript' },
              content (node) { return node.descendantsOfType('code') }
            },
            {
              type: 'template',
              language (node) { return 'html' },
              content (node) { return node.descendantsOfType('content') }
            }
          ]
        })

        atom.grammars.addGrammar(jsGrammar)
        atom.grammars.addGrammar(htmlGrammar)

        buffer.setText('<body>\n<script>\nb(<%= c.d %>)\n</script>\n</body>')
        const languageMode = new TreeSitterLanguageMode({buffer, grammar: ejsGrammar, grammars: atom.grammars})
        buffer.setLanguageMode(languageMode)

        // 4 parses: EJS, HTML, template JS, script tag JS
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)
        await nextHighlightingUpdate(languageMode)

        expectTokensToEqual(editor, [
          [
            {text: '<', scopes: ['html']},
            {text: 'body', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']}
          ],
          [
            {text: '<', scopes: ['html']},
            {text: 'script', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']}
          ],
          [
            {text: 'b', scopes: ['html', 'function']},
            {text: '(', scopes: ['html']},
            {text: '<%=', scopes: ['html', 'directive']},
            {text: ' c.', scopes: ['html']},
            {text: 'd', scopes: ['html', 'property']},
            {text: ' ', scopes: ['html']},
            {text: '%>', scopes: ['html', 'directive']},
            {text: ')', scopes: ['html']},
          ],
          [
            {text: '</', scopes: ['html']},
            {text: 'script', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']}
          ],
          [
            {text: '</', scopes: ['html']},
            {text: 'body', scopes: ['html', 'tag']},
            {text: '>', scopes: ['html']}
          ],
        ])
      })
    })
  })

  describe('folding', () => {
    it('can fold nodes that start and end with specified tokens', async () => {
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

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

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

    it('can fold nodes of specified types', async () => {
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

      buffer.setText(dedent `
        const element1 = <Element
          className='submit'
          id='something' />

        const element2 = <Element>
          <span>hello</span>
          <span>world</span>
        </Element>
      `)

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

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

    it('can fold entire nodes when no start or end parameters are specified', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          // By default, for a node with no children, folds are started at the *end* of the first
          // line of a node, and ended at the *beginning* of the last line.
          {type: 'comment'}
        ]
      })

      buffer.setText(dedent `
        /**
         * Important
         */
        const x = 1 /*
          Also important
        */
      `)

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

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

    it('tries each folding strategy for a given node in the order specified', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, cGrammarPath, {
        parser: 'tree-sitter-c',
        folds: [
          // If the #ifdef has an `#else` clause, then end the fold there.
          {
            type: ['preproc_ifdef', 'preproc_elif'],
            start: {index: 1},
            end: {type: ['preproc_else', 'preproc_elif']}
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

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

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

      editor.foldAllAtIndentLevel(1)
      expect(getDisplayText(editor)).toBe(dedent `
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32…
        #elif defined MACOS…
        #else…

        #endif

        #endif
      `)
    })

    it('does not fold when the start and end parameters match the same child', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
        parser: 'tree-sitter-html',
        folds: [
          {
            type: 'element',
            start: {index: 0},
            end: {index: -1}
          }
        ]
      })

      buffer.setText(dedent `
        <head>
        <meta name='key-1', content='value-1'>
        <meta name='key-2', content='value-2'>
        </head>
      `)

      const languageMode = new TreeSitterLanguageMode({buffer, grammar})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)

      // Void elements have only one child
      expect(editor.isFoldableAtBufferRow(1)).toBe(false)
      expect(editor.isFoldableAtBufferRow(2)).toBe(false)

      editor.foldBufferRow(0)
      expect(getDisplayText(editor)).toBe(dedent `
        <head>…
        </head>
      `)
    })

    describe('when folding a node that ends with a line break', () => {
      it('ends the fold at the end of the previous line', async () => {
        const grammar = new TreeSitterGrammar(atom.grammars, pythonGrammarPath, {
          parser: 'tree-sitter-python',
          folds: [
            {
              type: 'function_definition',
              start: {type: ':'}
            }
          ]
        })

        buffer.setText(dedent `
          def ab():
            print 'a'
            print 'b'

          def cd():
            print 'c'
            print 'd'
        `)

        buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
        await nextHighlightingUpdate(buffer.getLanguageMode())

        editor.foldBufferRow(0)
        expect(getDisplayText(editor)).toBe(dedent `
          def ab():…

          def cd():
            print 'c'
            print 'd'
        `)
      })
    })

    it('folds code in injected languages', async () => {
      const htmlGrammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
        id: 'html',
        parser: 'tree-sitter-html',
        scopes: {},
        folds: [{
          type: ['element', 'raw_element'],
          start: {index: 0},
          end: {index: -1}
        }],
        injectionRegExp: 'html'
      })

      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        id: 'javascript',
        parser: 'tree-sitter-javascript',
        scopes: {},
        folds: [{
          type: ['template_string'],
          start: {index: 0},
          end: {index: -1},
        },
        {
          start: {index: 0, type: '('},
          end: {index: -1, type: ')'}
        }],
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      })

      atom.grammars.addGrammar(htmlGrammar)

      buffer.setText(
        `a = html \`
            <div>
              c\${def(
                1,
                2,
                3,
              )}e\${f}g
            </div>
          \`
        `
      )
      const languageMode = new TreeSitterLanguageMode({buffer, grammar: jsGrammar, grammars: atom.grammars})
      buffer.setLanguageMode(languageMode)

      await nextHighlightingUpdate(languageMode)
      await nextHighlightingUpdate(languageMode)

      editor.foldBufferRow(2)
      expect(getDisplayText(editor)).toBe(
        `a = html \`
            <div>
              c\${def(…)}e\${f}g
            </div>
          \`
        `
      )

      editor.foldBufferRow(1)
      expect(getDisplayText(editor)).toBe(
        `a = html \`
            <div>…
            </div>
          \`
        `
      )

      editor.foldBufferRow(0)
      expect(getDisplayText(editor)).toBe(
        `a = html \`…\`
        `
      )
    })
  })

  describe('.scopeDescriptorForPosition', () => {
    it('returns a scope descriptor representing the given position in the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        id: 'javascript',
        parser: 'tree-sitter-javascript'
      })

      buffer.setText('foo({bar: baz});')

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      await nextHighlightingUpdate(buffer.getLanguageMode())
      expect(editor.scopeDescriptorForBufferPosition([0, 6]).getScopesArray()).toEqual([
        'javascript',
        'program',
        'expression_statement',
        'call_expression',
        'arguments',
        'object',
        'pair',
        'property_identifier'
      ])
    })

    it('includes nodes in injected syntax trees', async () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        id: 'javascript',
        parser: 'tree-sitter-javascript',
        scopes: {},
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      })

      const htmlGrammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
        id: 'html',
        parser: 'tree-sitter-html',
        scopes: {},
        injectionRegExp: 'html',
        injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
      })

      atom.grammars.addGrammar(jsGrammar)
      atom.grammars.addGrammar(htmlGrammar)

      buffer.setText(`
        <div>
          <script>
            html \`
              <span>\${person.name}</span>
            \`
          </script>
        </div>
      `)

      const languageMode = new TreeSitterLanguageMode({buffer, grammar: htmlGrammar, grammars: atom.grammars})
      buffer.setLanguageMode(languageMode)
      await nextHighlightingUpdate(languageMode)
      await nextHighlightingUpdate(languageMode)
      await nextHighlightingUpdate(languageMode)

      const position = buffer.findSync('name').start
      expect(languageMode.scopeDescriptorForPosition(position).getScopesArray()).toEqual([
        'html',
        'fragment',
        'element',
        'raw_element',
        'raw_text',
        'program',
        'expression_statement',
        'call_expression',
        'template_string',
        'fragment',
        'element',
        'template_substitution',
        'member_expression',
        'property_identifier'
      ])
    })
  })

  describe('TextEditor.selectLargerSyntaxNode and .selectSmallerSyntaxNode', () => {
    it('expands and contracts the selection based on the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {'program': 'source'}
      })

      buffer.setText(dedent `
        function a (b, c, d) {
          eee.f()
          g()
        }
      `)

      buffer.setLanguageMode(new TreeSitterLanguageMode({buffer, grammar}))
      await nextHighlightingUpdate(buffer.getLanguageMode())

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

    it('handles injected languages', async () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        id: 'javascript',
        parser: 'tree-sitter-javascript',
        scopes: {
          'property_identifier': 'property',
          'call_expression > identifier': 'function',
          'template_string': 'string',
          'template_substitution > "${"': 'interpolation',
          'template_substitution > "}"': 'interpolation'
        },
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      })

      const htmlGrammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
        id: 'html',
        parser: 'tree-sitter-html',
        scopes: {
          fragment: 'html',
          tag_name: 'tag',
          attribute_name: 'attr'
        },
        injectionRegExp: 'html'
      })

      atom.grammars.addGrammar(htmlGrammar)

      buffer.setText('a = html ` <b>c${def()}e${f}g</b> `')
      const languageMode = new TreeSitterLanguageMode({buffer, grammar: jsGrammar, grammars: atom.grammars})
      buffer.setLanguageMode(languageMode)

      await nextHighlightingUpdate(languageMode)
      await nextHighlightingUpdate(languageMode)

      editor.setCursorBufferPosition({row: 0, column: buffer.getText().indexOf('ef()')})
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('def')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('def()')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('${def()}')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('c${def()}e${f}g')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('<b>c${def()}e${f}g</b>')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe(' <b>c${def()}e${f}g</b> ')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('` <b>c${def()}e${f}g</b> `')
      editor.selectLargerSyntaxNode()
      expect(editor.getSelectedText()).toBe('html ` <b>c${def()}e${f}g</b> `')
    })
  })
})

function nextHighlightingUpdate (languageMode) {
  return new Promise(resolve => {
    const subscription = languageMode.onDidChangeHighlighting(() => {
      subscription.dispose()
      resolve()
    })
  })
}

function getDisplayText (editor) {
  return editor.displayLayer.getText()
}

function expectTokensToEqual (editor, expectedTokenLines) {
  const lastRow = editor.getLastScreenRow()

  // Assert that the correct tokens are returned regardless of which row
  // the highlighting iterator starts on.
  for (let startRow = 0; startRow <= lastRow; startRow++) {

    // Clear the screen line cache between iterations, but not on the first
    // iteration, so that the first iteration tests that the cache has been
    // correctly invalidated by any changes.
    if (startRow > 0) {
      editor.displayLayer.clearSpatialIndex()
    }

    editor.displayLayer.getScreenLines(startRow, Infinity)

    const tokenLines = []
    for (let row = startRow; row <= lastRow; row++) {
      tokenLines[row] = editor.tokensForScreenRow(row).map(({text, scopes}) => ({
        text,
        scopes: scopes.map(scope => scope
          .split(' ')
          .map(className => className.replace('syntax--', ''))
          .join(' '))
      }))
    }

    for (let row = startRow; row <= lastRow; row++) {
      const tokenLine = tokenLines[row]
      const expectedTokenLine = expectedTokenLines[row]

      expect(tokenLine.length).toEqual(expectedTokenLine.length)
      for (let i = 0; i < tokenLine.length; i++) {
        expect(tokenLine[i]).toEqual(expectedTokenLine[i], `Token ${i}, startRow: ${startRow}`)
      }
    }
  }

  // Fully populate the screen line cache again so that cache invalidation
  // due to subsequent edits can be tested.
  editor.displayLayer.getScreenLines(0, Infinity)
}

const HTML_TEMPLATE_LITERAL_INJECTION_POINT = {
  type: 'call_expression',
  language (node) {
    if (node.lastChild.type === 'template_string' && node.firstChild.type === 'identifier') {
      return node.firstChild.text
    }
  },
  content (node) {
    return node.lastChild
  }
}

const SCRIPT_TAG_INJECTION_POINT = {
  type: 'raw_element',
  language () { return 'javascript' },
  content (node) { return node.child(1) }
}
