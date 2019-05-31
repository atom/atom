/* eslint-disable no-template-curly-in-string */

const fs = require('fs');
const path = require('path');
const dedent = require('dedent');
const TextBuffer = require('text-buffer');
const { Point } = TextBuffer;
const TextEditor = require('../src/text-editor');
const TreeSitterGrammar = require('../src/tree-sitter-grammar');
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode');
const Random = require('../script/node_modules/random-seed');
const { getRandomBufferRange, buildRandomLines } = require('./helpers/random');

const cGrammarPath = require.resolve('language-c/grammars/tree-sitter-c.cson');
const pythonGrammarPath = require.resolve(
  'language-python/grammars/tree-sitter-python.cson'
);
const jsGrammarPath = require.resolve(
  'language-javascript/grammars/tree-sitter-javascript.cson'
);
const htmlGrammarPath = require.resolve(
  'language-html/grammars/tree-sitter-html.cson'
);
const ejsGrammarPath = require.resolve(
  'language-html/grammars/tree-sitter-ejs.cson'
);
const rubyGrammarPath = require.resolve(
  'language-ruby/grammars/tree-sitter-ruby.cson'
);

describe('TreeSitterLanguageMode', () => {
  let editor, buffer;

  beforeEach(async () => {
    editor = await atom.workspace.open('');
    buffer = editor.getBuffer();
    editor.displayLayer.reset({ foldCharacter: '…' });
  });

  describe('highlighting', () => {
    it('applies the most specific scope mapping to each node in the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source',
          'call_expression > identifier': 'function',
          property_identifier: 'property',
          'call_expression > member_expression > property_identifier': 'method'
        }
      });

      buffer.setText('aa.bbb = cc(d.eee());');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [
          { text: 'aa.', scopes: ['source'] },
          { text: 'bbb', scopes: ['source', 'property'] },
          { text: ' = ', scopes: ['source'] },
          { text: 'cc', scopes: ['source', 'function'] },
          { text: '(d.', scopes: ['source'] },
          { text: 'eee', scopes: ['source', 'method'] },
          { text: '());', scopes: ['source'] }
        ]
      ]);
    });

    it('can start or end multiple scopes at the same position', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source',
          call_expression: 'call',
          member_expression: 'member',
          identifier: 'variable',
          '"("': 'open-paren',
          '")"': 'close-paren'
        }
      });

      buffer.setText('a = bb.ccc();');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [
          { text: 'a', scopes: ['source', 'variable'] },
          { text: ' = ', scopes: ['source'] },
          { text: 'bb', scopes: ['source', 'call', 'member', 'variable'] },
          { text: '.ccc', scopes: ['source', 'call', 'member'] },
          { text: '(', scopes: ['source', 'call', 'open-paren'] },
          { text: ')', scopes: ['source', 'call', 'close-paren'] },
          { text: ';', scopes: ['source'] }
        ]
      ]);
    });

    it('can resume highlighting on a line that starts with whitespace', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'call_expression > member_expression > property_identifier':
            'function',
          property_identifier: 'member',
          identifier: 'variable'
        }
      });

      buffer.setText('a\n  .b();');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [{ text: 'a', scopes: ['variable'] }],
        [
          { text: '  ', scopes: ['leading-whitespace'] },
          { text: '.', scopes: [] },
          { text: 'b', scopes: ['function'] },
          { text: '();', scopes: [] }
        ]
      ]);
    });

    it('correctly skips over tokens with zero size', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, cGrammarPath, {
        parser: 'tree-sitter-c',
        scopes: {
          primitive_type: 'type',
          identifier: 'variable'
        }
      });

      buffer.setText('int main() {\n  int a\n  int b;\n}');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expect(
        languageMode.tree.rootNode
          .descendantForPosition(Point(1, 2), Point(1, 6))
          .toString()
      ).toBe('(declaration (primitive_type) (identifier) (MISSING ";"))');

      expectTokensToEqual(editor, [
        [
          { text: 'int', scopes: ['type'] },
          { text: ' ', scopes: [] },
          { text: 'main', scopes: ['variable'] },
          { text: '() {', scopes: [] }
        ],
        [
          { text: '  ', scopes: ['leading-whitespace'] },
          { text: 'int', scopes: ['type'] },
          { text: ' ', scopes: [] },
          { text: 'a', scopes: ['variable'] }
        ],
        [
          { text: '  ', scopes: ['leading-whitespace'] },
          { text: 'int', scopes: ['type'] },
          { text: ' ', scopes: [] },
          { text: 'b', scopes: ['variable'] },
          { text: ';', scopes: [] }
        ],
        [{ text: '}', scopes: [] }]
      ]);
    });

    it("updates lines' highlighting when they are affected by distant changes", async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'call_expression > identifier': 'function',
          property_identifier: 'member'
        }
      });

      buffer.setText('a(\nb,\nc\n');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      // missing closing paren
      expectTokensToEqual(editor, [
        [{ text: 'a(', scopes: [] }],
        [{ text: 'b,', scopes: [] }],
        [{ text: 'c', scopes: [] }],
        [{ text: '', scopes: [] }]
      ]);

      buffer.append(')');
      expectTokensToEqual(editor, [
        [{ text: 'a', scopes: ['function'] }, { text: '(', scopes: [] }],
        [{ text: 'b,', scopes: [] }],
        [{ text: 'c', scopes: [] }],
        [{ text: ')', scopes: [] }]
      ]);
    });

    it('allows comma-separated selectors as scope mapping keys', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          'identifier, call_expression > identifier': [
            { match: '^[A-Z]', scopes: 'constructor' }
          ],

          'call_expression > identifier': 'function'
        }
      });

      buffer.setText(`a(B(new C))`);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [
          { text: 'a', scopes: ['function'] },
          { text: '(', scopes: [] },
          { text: 'B', scopes: ['constructor'] },
          { text: '(new ', scopes: [] },
          { text: 'C', scopes: ['constructor'] },
          { text: '))', scopes: [] }
        ]
      ]);
    });

    it('handles edits after tokens that end between CR and LF characters (regression)', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          comment: 'comment',
          string: 'string',
          property_identifier: 'property'
        }
      });

      buffer.setText(['// abc', '', 'a("b").c'].join('\r\n'));

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [{ text: '// abc', scopes: ['comment'] }],
        [{ text: '', scopes: [] }],
        [
          { text: 'a(', scopes: [] },
          { text: '"b"', scopes: ['string'] },
          { text: ').', scopes: [] },
          { text: 'c', scopes: ['property'] }
        ]
      ]);

      buffer.insert([2, 0], '  ');
      expectTokensToEqual(editor, [
        [{ text: '// abc', scopes: ['comment'] }],
        [{ text: '', scopes: [] }],
        [
          { text: '  ', scopes: ['leading-whitespace'] },
          { text: 'a(', scopes: [] },
          { text: '"b"', scopes: ['string'] },
          { text: ').', scopes: [] },
          { text: 'c', scopes: ['property'] }
        ]
      ]);
    });

    it('handles multi-line nodes with children on different lines (regression)', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          template_string: 'string',
          '"${"': 'interpolation',
          '"}"': 'interpolation'
        }
      });

      buffer.setText('`\na${1}\nb${2}\n`;');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [{ text: '`', scopes: ['string'] }],
        [
          { text: 'a', scopes: ['string'] },
          { text: '${', scopes: ['string', 'interpolation'] },
          { text: '1', scopes: ['string'] },
          { text: '}', scopes: ['string', 'interpolation'] }
        ],
        [
          { text: 'b', scopes: ['string'] },
          { text: '${', scopes: ['string', 'interpolation'] },
          { text: '2', scopes: ['string'] },
          { text: '}', scopes: ['string', 'interpolation'] }
        ],
        [{ text: '`', scopes: ['string'] }, { text: ';', scopes: [] }]
      ]);
    });

    it('handles folds inside of highlighted tokens', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          comment: 'comment',
          'call_expression > identifier': 'function'
        }
      });

      buffer.setText(dedent`
        /*
         * Hello
         */

        hello();
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      editor.foldBufferRange([[0, 2], [2, 0]]);

      expectTokensToEqual(editor, [
        [
          { text: '/*', scopes: ['comment'] },
          { text: '…', scopes: ['fold-marker'] },
          { text: ' */', scopes: ['comment'] }
        ],
        [{ text: '', scopes: [] }],
        [{ text: 'hello', scopes: ['function'] }, { text: '();', scopes: [] }]
      ]);
    });

    it('applies regex match rules when specified', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: {
          identifier: [
            { match: '^(exports|document|window|global)$', scopes: 'global' },
            { match: '^[A-Z_]+$', scopes: 'constant' },
            { match: '^[A-Z]', scopes: 'constructor' },
            'variable'
          ]
        }
      });

      buffer.setText(`exports.object = Class(SOME_CONSTANT, x)`);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [
          { text: 'exports', scopes: ['global'] },
          { text: '.object = ', scopes: [] },
          { text: 'Class', scopes: ['constructor'] },
          { text: '(', scopes: [] },
          { text: 'SOME_CONSTANT', scopes: ['constant'] },
          { text: ', ', scopes: [] },
          { text: 'x', scopes: ['variable'] },
          { text: ')', scopes: [] }
        ]
      ]);
    });

    it('handles nodes that start before their first child and end after their last child', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, rubyGrammarPath, {
        parser: 'tree-sitter-ruby',
        scopes: {
          bare_string: 'string',
          interpolation: 'embedded',
          '"#{"': 'punctuation',
          '"}"': 'punctuation'
        }
      });

      // The bare string node `bc#{d}ef` has one child: the interpolation, and that child
      // starts later and ends earlier than the bare string.
      buffer.setText('a = %W( bc#{d}ef )');

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expectTokensToEqual(editor, [
        [
          { text: 'a = %W( ', scopes: [] },
          { text: 'bc', scopes: ['string'] },
          { text: '#{', scopes: ['string', 'embedded', 'punctuation'] },
          { text: 'd', scopes: ['string', 'embedded'] },
          { text: '}', scopes: ['string', 'embedded', 'punctuation'] },
          { text: 'ef', scopes: ['string'] },
          { text: ' )', scopes: [] }
        ]
      ]);
    });

    describe('when the buffer changes during a parse', () => {
      it('immediately parses again when the current parse completes', async () => {
        const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          parser: 'tree-sitter-javascript',
          scopes: {
            identifier: 'variable',
            'call_expression > identifier': 'function',
            'new_expression > identifier': 'constructor'
          }
        });

        buffer.setText('abc;');

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar,
          syncTimeoutMicros: 0
        });
        buffer.setLanguageMode(languageMode);
        await nextHighlightingUpdate(languageMode);
        await new Promise(process.nextTick);

        expectTokensToEqual(editor, [
          [{ text: 'abc', scopes: ['variable'] }, { text: ';', scopes: [] }]
        ]);

        buffer.setTextInRange([[0, 3], [0, 3]], '()');
        expectTokensToEqual(editor, [
          [{ text: 'abc()', scopes: ['variable'] }, { text: ';', scopes: [] }]
        ]);

        buffer.setTextInRange([[0, 0], [0, 0]], 'new ');
        expectTokensToEqual(editor, [
          [
            { text: 'new ', scopes: [] },
            { text: 'abc()', scopes: ['variable'] },
            { text: ';', scopes: [] }
          ]
        ]);

        await nextHighlightingUpdate(languageMode);
        expectTokensToEqual(editor, [
          [
            { text: 'new ', scopes: [] },
            { text: 'abc', scopes: ['function'] },
            { text: '();', scopes: [] }
          ]
        ]);

        await nextHighlightingUpdate(languageMode);
        expectTokensToEqual(editor, [
          [
            { text: 'new ', scopes: [] },
            { text: 'abc', scopes: ['constructor'] },
            { text: '();', scopes: [] }
          ]
        ]);
      });
    });

    describe('when changes are small enough to be re-parsed synchronously', () => {
      it('can incorporate multiple consecutive synchronous updates', () => {
        const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          parser: 'tree-sitter-javascript',
          scopes: {
            property_identifier: 'property',
            'call_expression > identifier': 'function',
            'call_expression > member_expression > property_identifier':
              'method'
          }
        });

        const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
        buffer.setLanguageMode(languageMode);
        buffer.setText('a');
        expectTokensToEqual(editor, [[{ text: 'a', scopes: [] }]]);

        buffer.append('.');
        expectTokensToEqual(editor, [[{ text: 'a.', scopes: [] }]]);

        buffer.append('b');
        expectTokensToEqual(editor, [
          [{ text: 'a.', scopes: [] }, { text: 'b', scopes: ['property'] }]
        ]);

        buffer.append('()');
        expectTokensToEqual(editor, [
          [
            { text: 'a.', scopes: [] },
            { text: 'b', scopes: ['method'] },
            { text: '()', scopes: [] }
          ]
        ]);

        buffer.delete([[0, 1], [0, 2]]);
        expectTokensToEqual(editor, [
          [{ text: 'ab', scopes: ['function'] }, { text: '()', scopes: [] }]
        ]);
      });
    });

    describe('injectionPoints and injectionPatterns', () => {
      let jsGrammar, htmlGrammar;

      beforeEach(() => {
        jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {
            comment: 'comment',
            property_identifier: 'property',
            'call_expression > identifier': 'function',
            template_string: 'string',
            'template_substitution > "${"': 'interpolation',
            'template_substitution > "}"': 'interpolation'
          },
          injectionRegExp: 'javascript',
          injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
        });

        htmlGrammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
          scopeName: 'html',
          parser: 'tree-sitter-html',
          scopes: {
            fragment: 'html',
            tag_name: 'tag',
            attribute_name: 'attr'
          },
          injectionRegExp: 'html',
          injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
        });
      });

      it('highlights code inside of injection points', async () => {
        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);
        buffer.setText('node.innerHTML = html `\na ${b}<img src="d">\n`;');

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: jsGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: 'node.', scopes: [] },
            { text: 'innerHTML', scopes: ['property'] },
            { text: ' = ', scopes: [] },
            { text: 'html', scopes: ['function'] },
            { text: ' ', scopes: [] },
            { text: '`', scopes: ['string'] },
            { text: '', scopes: ['string', 'html'] }
          ],
          [
            { text: 'a ', scopes: ['string', 'html'] },
            { text: '${', scopes: ['string', 'html', 'interpolation'] },
            { text: 'b', scopes: ['string', 'html'] },
            { text: '}', scopes: ['string', 'html', 'interpolation'] },
            { text: '<', scopes: ['string', 'html'] },
            { text: 'img', scopes: ['string', 'html', 'tag'] },
            { text: ' ', scopes: ['string', 'html'] },
            { text: 'src', scopes: ['string', 'html', 'attr'] },
            { text: '="d">', scopes: ['string', 'html'] }
          ],
          [{ text: '`', scopes: ['string'] }, { text: ';', scopes: [] }]
        ]);

        const range = buffer.findSync('html');
        buffer.setTextInRange(range, 'xml');
        await nextHighlightingUpdate(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: 'node.', scopes: [] },
            { text: 'innerHTML', scopes: ['property'] },
            { text: ' = ', scopes: [] },
            { text: 'xml', scopes: ['function'] },
            { text: ' ', scopes: [] },
            { text: '`', scopes: ['string'] }
          ],
          [
            { text: 'a ', scopes: ['string'] },
            { text: '${', scopes: ['string', 'interpolation'] },
            { text: 'b', scopes: ['string'] },
            { text: '}', scopes: ['string', 'interpolation'] },
            { text: '<img src="d">', scopes: ['string'] }
          ],
          [{ text: '`', scopes: ['string'] }, { text: ';', scopes: [] }]
        ]);
      });

      it('highlights the content after injections', async () => {
        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);
        buffer.setText('<script>\nhello();\n</script>\n<div>\n</div>');

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: htmlGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: '<', scopes: ['html'] },
            { text: 'script', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: 'hello', scopes: ['html', 'function'] },
            { text: '();', scopes: ['html'] }
          ],
          [
            { text: '</', scopes: ['html'] },
            { text: 'script', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: '<', scopes: ['html'] },
            { text: 'div', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: '</', scopes: ['html'] },
            { text: 'div', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ]
        ]);
      });

      it('updates buffers highlighting when a grammar with injectionRegExp is added', async () => {
        atom.grammars.addGrammar(jsGrammar);

        buffer.setText('node.innerHTML = html `\na ${b}<img src="d">\n`;');
        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: jsGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: 'node.', scopes: [] },
            { text: 'innerHTML', scopes: ['property'] },
            { text: ' = ', scopes: [] },
            { text: 'html', scopes: ['function'] },
            { text: ' ', scopes: [] },
            { text: '`', scopes: ['string'] }
          ],
          [
            { text: 'a ', scopes: ['string'] },
            { text: '${', scopes: ['string', 'interpolation'] },
            { text: 'b', scopes: ['string'] },
            { text: '}', scopes: ['string', 'interpolation'] },
            { text: '<img src="d">', scopes: ['string'] }
          ],
          [{ text: '`', scopes: ['string'] }, { text: ';', scopes: [] }]
        ]);

        atom.grammars.addGrammar(htmlGrammar);
        await nextHighlightingUpdate(languageMode);
        expectTokensToEqual(editor, [
          [
            { text: 'node.', scopes: [] },
            { text: 'innerHTML', scopes: ['property'] },
            { text: ' = ', scopes: [] },
            { text: 'html', scopes: ['function'] },
            { text: ' ', scopes: [] },
            { text: '`', scopes: ['string'] },
            { text: '', scopes: ['string', 'html'] }
          ],
          [
            { text: 'a ', scopes: ['string', 'html'] },
            { text: '${', scopes: ['string', 'html', 'interpolation'] },
            { text: 'b', scopes: ['string', 'html'] },
            { text: '}', scopes: ['string', 'html', 'interpolation'] },
            { text: '<', scopes: ['string', 'html'] },
            { text: 'img', scopes: ['string', 'html', 'tag'] },
            { text: ' ', scopes: ['string', 'html'] },
            { text: 'src', scopes: ['string', 'html', 'attr'] },
            { text: '="d">', scopes: ['string', 'html'] }
          ],
          [{ text: '`', scopes: ['string'] }, { text: ';', scopes: [] }]
        ]);
      });

      it('handles injections that intersect', async () => {
        const ejsGrammar = new TreeSitterGrammar(
          atom.grammars,
          ejsGrammarPath,
          {
            id: 'ejs',
            parser: 'tree-sitter-embedded-template',
            scopes: {
              '"<%="': 'directive',
              '"%>"': 'directive'
            },
            injectionPoints: [
              {
                type: 'template',
                language(node) {
                  return 'javascript';
                },
                content(node) {
                  return node.descendantsOfType('code');
                }
              },
              {
                type: 'template',
                language(node) {
                  return 'html';
                },
                content(node) {
                  return node.descendantsOfType('content');
                }
              }
            ]
          }
        );

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);

        buffer.setText('<body>\n<script>\nb(<%= c.d %>)\n</script>\n</body>');
        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: ejsGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: '<', scopes: ['html'] },
            { text: 'body', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: '<', scopes: ['html'] },
            { text: 'script', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: 'b', scopes: ['html', 'function'] },
            { text: '(', scopes: ['html'] },
            { text: '<%=', scopes: ['html', 'directive'] },
            { text: ' c.', scopes: ['html'] },
            { text: 'd', scopes: ['html', 'property'] },
            { text: ' ', scopes: ['html'] },
            { text: '%>', scopes: ['html', 'directive'] },
            { text: ')', scopes: ['html'] }
          ],
          [
            { text: '</', scopes: ['html'] },
            { text: 'script', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ],
          [
            { text: '</', scopes: ['html'] },
            { text: 'body', scopes: ['html', 'tag'] },
            { text: '>', scopes: ['html'] }
          ]
        ]);
      });

      it('terminates comment token at the end of an injection, so that the next injection is NOT a continuation of the comment', async () => {
        const ejsGrammar = new TreeSitterGrammar(
          atom.grammars,
          ejsGrammarPath,
          {
            id: 'ejs',
            parser: 'tree-sitter-embedded-template',
            scopes: {
              '"<%"': 'directive',
              '"%>"': 'directive'
            },
            injectionPoints: [
              {
                type: 'template',
                language(node) {
                  return 'javascript';
                },
                content(node) {
                  return node.descendantsOfType('code');
                },
                newlinesBetween: true
              },
              {
                type: 'template',
                language(node) {
                  return 'html';
                },
                content(node) {
                  return node.descendantsOfType('content');
                }
              }
            ]
          }
        );

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);

        buffer.setText('<% // js comment %>\n<% b() %>');
        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: ejsGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        expectTokensToEqual(editor, [
          [
            { text: '<%', scopes: ['directive'] },
            { text: ' ', scopes: [] },
            { text: '// js comment ', scopes: ['comment'] },
            { text: '%>', scopes: ['directive'] },
            { text: '', scopes: ['html'] }
          ],
          [
            { text: '<%', scopes: ['directive'] },
            { text: ' ', scopes: [] },
            { text: 'b', scopes: ['function'] },
            { text: '() ', scopes: [] },
            { text: '%>', scopes: ['directive'] }
          ]
        ]);
      });

      it('notifies onDidTokenize listeners the first time all syntax highlighting is done', async () => {
        const promise = new Promise(resolve => {
          editor.onDidTokenize(event => {
            expectTokensToEqual(editor, [
              [
                { text: '<', scopes: ['html'] },
                { text: 'script', scopes: ['html', 'tag'] },
                { text: '>', scopes: ['html'] }
              ],
              [
                { text: 'hello', scopes: ['html', 'function'] },
                { text: '();', scopes: ['html'] }
              ],
              [
                { text: '</', scopes: ['html'] },
                { text: 'script', scopes: ['html', 'tag'] },
                { text: '>', scopes: ['html'] }
              ]
            ]);
            resolve();
          });
        });

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);
        buffer.setText('<script>\nhello();\n</script>');

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: htmlGrammar,
          grammars: atom.grammars,
          syncTimeoutMicros: 0
        });
        buffer.setLanguageMode(languageMode);

        await promise;
      });
    });
  });

  describe('highlighting after random changes', () => {
    let originalTimeout;

    beforeEach(() => {
      originalTimeout = jasmine.getEnv().defaultTimeoutInterval;
      jasmine.getEnv().defaultTimeoutInterval = 60 * 1000;
    });

    afterEach(() => {
      jasmine.getEnv().defaultTimeoutInterval = originalTimeout;
    });

    it('matches the highlighting of a freshly-opened editor', async () => {
      jasmine.useRealClock();

      const text = fs.readFileSync(
        path.join(__dirname, 'fixtures', 'sample.js'),
        'utf8'
      );
      atom.grammars.loadGrammarSync(jsGrammarPath);
      atom.grammars.assignLanguageMode(buffer, 'source.js');
      buffer.getLanguageMode().syncTimeoutMicros = 0;

      const initialSeed = Date.now();
      for (let i = 0, trialCount = 10; i < trialCount; i++) {
        let seed = initialSeed + i;
        // seed = 1541201470759
        const random = Random(seed);

        // Parse the initial content and render all of the screen lines.
        buffer.setText(text);
        buffer.clearUndoStack();
        await buffer.getLanguageMode().parseCompletePromise();
        editor.displayLayer.getScreenLines();

        // Make several random edits.
        for (let j = 0, editCount = 1 + random(4); j < editCount; j++) {
          const editRoll = random(10);
          const range = getRandomBufferRange(random, buffer);

          if (editRoll < 2) {
            const linesToInsert = buildRandomLines(
              random,
              range.getExtent().row + 1
            );
            // console.log('replace', range.toString(), JSON.stringify(linesToInsert))
            buffer.setTextInRange(range, linesToInsert);
          } else if (editRoll < 5) {
            // console.log('delete', range.toString())
            buffer.delete(range);
          } else {
            const linesToInsert = buildRandomLines(random, 3);
            // console.log('insert', range.start.toString(), JSON.stringify(linesToInsert))
            buffer.insert(range.start, linesToInsert);
          }

          // console.log(buffer.getText())

          // Sometimes, let the parse complete before re-rendering.
          // Sometimes re-render and move on before the parse completes.
          if (random(2)) await buffer.getLanguageMode().parseCompletePromise();
          editor.displayLayer.getScreenLines();
        }

        // Revert the edits, because Tree-sitter's error recovery is somewhat path-dependent,
        // and we want a state where the tree parse result is guaranteed.
        while (buffer.undo()) {}

        // Create a fresh buffer and editor with the same text.
        const buffer2 = new TextBuffer(buffer.getText());
        const editor2 = new TextEditor({ buffer: buffer2 });
        atom.grammars.assignLanguageMode(buffer2, 'source.js');

        // Verify that the the two buffers have the same syntax highlighting.
        await buffer.getLanguageMode().parseCompletePromise();
        await buffer2.getLanguageMode().parseCompletePromise();
        expect(buffer.getLanguageMode().tree.rootNode.toString()).toEqual(
          buffer2.getLanguageMode().tree.rootNode.toString(),
          `Seed: ${seed}`
        );

        for (let j = 0, n = editor.getScreenLineCount(); j < n; j++) {
          const tokens1 = editor.tokensForScreenRow(j);
          const tokens2 = editor2.tokensForScreenRow(j);
          expect(tokens1).toEqual(tokens2, `Seed: ${seed}, screen line: ${j}`);
          if (jasmine.getEnv().currentSpec.results().failedCount > 0) {
            console.log(tokens1);
            console.log(tokens2);
            debugger; // eslint-disable-line no-debugger
            break;
          }
        }

        if (jasmine.getEnv().currentSpec.results().failedCount > 0) break;
      }
    });
  });

  describe('folding', () => {
    it('can fold nodes that start and end with specified tokens', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {
            start: { type: '{', index: 0 },
            end: { type: '}', index: -1 }
          },
          {
            start: { type: '(', index: 0 },
            end: { type: ')', index: -1 }
          }
        ]
      });

      buffer.setText(dedent`
        module.exports =
        class A {
          getB (c,
                d,
                e) {
            return this.f(g)
          }
        }
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expect(editor.isFoldableAtBufferRow(0)).toBe(false);
      expect(editor.isFoldableAtBufferRow(1)).toBe(true);
      expect(editor.isFoldableAtBufferRow(2)).toBe(true);
      expect(editor.isFoldableAtBufferRow(3)).toBe(false);
      expect(editor.isFoldableAtBufferRow(4)).toBe(true);
      expect(editor.isFoldableAtBufferRow(5)).toBe(false);

      editor.foldBufferRow(2);
      expect(getDisplayText(editor)).toBe(dedent`
        module.exports =
        class A {
          getB (c,…) {
            return this.f(g)
          }
        }
      `);

      editor.foldBufferRow(4);
      expect(getDisplayText(editor)).toBe(dedent`
        module.exports =
        class A {
          getB (c,…) {…}
        }
      `);
    });

    it('folds entire buffer rows when necessary to keep words on separate lines', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {
            start: { type: '{', index: 0 },
            end: { type: '}', index: -1 }
          },
          {
            start: { type: '(', index: 0 },
            end: { type: ')', index: -1 }
          }
        ]
      });

      buffer.setText(dedent`
        if (a) {
          b
        } else if (c) {
          d
        } else {
          e
        }
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      // Avoid bringing the `else if...` up onto the same screen line as the preceding `if`.
      editor.foldBufferRow(1);
      editor.foldBufferRow(3);
      expect(getDisplayText(editor)).toBe(dedent`
        if (a) {…
        } else if (c) {…
        } else {
          e
        }
      `);

      // It's ok to bring the final `}` onto the same screen line as the preceding `else`.
      editor.foldBufferRow(5);
      expect(getDisplayText(editor)).toBe(dedent`
        if (a) {…
        } else if (c) {…
        } else {…}
      `);
    });

    it('can fold nodes of specified types', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          // Start the fold after the first child (the opening tag) and end it at the last child
          // (the closing tag).
          {
            type: 'jsx_element',
            start: { index: 0 },
            end: { index: -1 }
          },

          // End the fold at the *second* to last child of the self-closing tag: the `/`.
          {
            type: 'jsx_self_closing_element',
            start: { index: 1 },
            end: { index: -2 }
          }
        ]
      });

      buffer.setText(dedent`
        const element1 = <Element
          className='submit'
          id='something' />

        const element2 = <Element>
          <span>hello</span>
          <span>world</span>
        </Element>
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expect(editor.isFoldableAtBufferRow(0)).toBe(true);
      expect(editor.isFoldableAtBufferRow(1)).toBe(false);
      expect(editor.isFoldableAtBufferRow(2)).toBe(false);
      expect(editor.isFoldableAtBufferRow(3)).toBe(false);
      expect(editor.isFoldableAtBufferRow(4)).toBe(true);
      expect(editor.isFoldableAtBufferRow(5)).toBe(false);

      editor.foldBufferRow(0);
      expect(getDisplayText(editor)).toBe(dedent`
        const element1 = <Element…/>

        const element2 = <Element>
          <span>hello</span>
          <span>world</span>
        </Element>
      `);

      editor.foldBufferRow(4);
      expect(getDisplayText(editor)).toBe(dedent`
        const element1 = <Element…/>

        const element2 = <Element>…
        </Element>
      `);
    });

    it('can fold entire nodes when no start or end parameters are specified', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          // By default, for a node with no children, folds are started at the *end* of the first
          // line of a node, and ended at the *beginning* of the last line.
          { type: 'comment' }
        ]
      });

      buffer.setText(dedent`
        /**
         * Important
         */
        const x = 1 /*
          Also important
        */
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expect(editor.isFoldableAtBufferRow(0)).toBe(true);
      expect(editor.isFoldableAtBufferRow(1)).toBe(false);
      expect(editor.isFoldableAtBufferRow(2)).toBe(false);
      expect(editor.isFoldableAtBufferRow(3)).toBe(true);
      expect(editor.isFoldableAtBufferRow(4)).toBe(false);

      editor.foldBufferRow(0);
      expect(getDisplayText(editor)).toBe(dedent`
        /**… */
        const x = 1 /*
          Also important
        */
      `);

      editor.foldBufferRow(3);
      expect(getDisplayText(editor)).toBe(dedent`
        /**… */
        const x = 1 /*…*/
      `);
    });

    it('tries each folding strategy for a given node in the order specified', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, cGrammarPath, {
        parser: 'tree-sitter-c',
        folds: [
          // If the #ifdef has an `#else` clause, then end the fold there.
          {
            type: ['preproc_ifdef', 'preproc_elif'],
            start: { index: 1 },
            end: { type: ['preproc_else', 'preproc_elif'] }
          },

          // Otherwise, end the fold at the last child - the `#endif`.
          {
            type: 'preproc_ifdef',
            start: { index: 1 },
            end: { index: -1 }
          },

          // When folding an `#else` clause, the fold extends to the end of the clause.
          {
            type: 'preproc_else',
            start: { index: 0 }
          }
        ]
      });

      buffer.setText(dedent`
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
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      editor.foldBufferRow(3);
      expect(getDisplayText(editor)).toBe(dedent`
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
      `);

      editor.foldBufferRow(8);
      expect(getDisplayText(editor)).toBe(dedent`
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32…
        #elif defined MACOS…
        #else

        #include <dirent.h>
        const char *path_separator = "/";

        #endif

        #endif
      `);

      editor.foldBufferRow(0);
      expect(getDisplayText(editor)).toBe(dedent`
        #ifndef FOO_H_…
        #endif
      `);

      editor.foldAllAtIndentLevel(1);
      expect(getDisplayText(editor)).toBe(dedent`
        #ifndef FOO_H_
        #define FOO_H_

        #ifdef _WIN32…
        #elif defined MACOS…
        #else…

        #endif

        #endif
      `);
    });

    it('does not fold when the start and end parameters match the same child', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, htmlGrammarPath, {
        parser: 'tree-sitter-html',
        folds: [
          {
            type: 'element',
            start: { index: 0 },
            end: { index: -1 }
          }
        ]
      });

      buffer.setText(dedent`
        <head>
        <meta name='key-1', content='value-1'>
        <meta name='key-2', content='value-2'>
        </head>
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      // Void elements have only one child
      expect(editor.isFoldableAtBufferRow(1)).toBe(false);
      expect(editor.isFoldableAtBufferRow(2)).toBe(false);

      editor.foldBufferRow(0);
      expect(getDisplayText(editor)).toBe(dedent`
        <head>…
        </head>
      `);
    });

    it('can target named vs anonymous nodes as fold boundaries', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, rubyGrammarPath, {
        parser: 'tree-sitter-ruby',
        folds: [
          // Note that this isn't how folds actually work in language-ruby. It's
          // just to demonstrate the targeting of named vs anonymous nodes.
          {
            type: 'elsif',
            start: { index: 1 },

            // There are no double quotes around the `elsif` type. This indicates
            // that we're targeting a *named* node in the syntax tree. The fold
            // should end at the nested `elsif` node, not at the token that represents
            // the literal string "elsif".
            end: { type: ['else', 'elsif'] }
          },
          {
            type: 'else',

            // There are double quotes around the `else` type. This indicates that
            // we're targetting an *anonymous* node in the syntax tree. The fold
            // should start at the token representing the literal string "else",
            // not at an `else` node.
            start: { type: '"else"' }
          }
        ]
      });

      buffer.setText(dedent`
        if a
          b
        elsif c
          d
        else
          e
        end
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);

      expect(languageMode.tree.rootNode.toString()).toBe(
        '(program (if (identifier) (then ' +
          '(identifier)) ' +
          '(elsif (identifier) (then ' +
          '(identifier)) ' +
          '(else ' +
          '(identifier)))))'
      );

      editor.foldBufferRow(2);
      expect(getDisplayText(editor)).toBe(dedent`
        if a
          b
        elsif c…
        else
          e
        end
      `);

      editor.foldBufferRow(4);
      expect(getDisplayText(editor)).toBe(dedent`
        if a
          b
        elsif c…
        else…
        end
      `);
    });

    it('updates fold locations when the buffer changes', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        folds: [
          {
            start: { type: '{', index: 0 },
            end: { type: '}', index: -1 }
          }
        ]
      });

      buffer.setText(dedent`
        class A {
          // a
          constructor (b) {
            this.b = b
          }
        }
      `);

      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);
      expect(languageMode.isFoldableAtRow(0)).toBe(true);
      expect(languageMode.isFoldableAtRow(1)).toBe(false);
      expect(languageMode.isFoldableAtRow(2)).toBe(true);
      expect(languageMode.isFoldableAtRow(3)).toBe(false);
      expect(languageMode.isFoldableAtRow(4)).toBe(false);

      buffer.insert([0, 0], '\n');
      expect(languageMode.isFoldableAtRow(0)).toBe(false);
      expect(languageMode.isFoldableAtRow(1)).toBe(true);
      expect(languageMode.isFoldableAtRow(2)).toBe(false);
      expect(languageMode.isFoldableAtRow(3)).toBe(true);
      expect(languageMode.isFoldableAtRow(4)).toBe(false);
    });

    describe('when folding a node that ends with a line break', () => {
      it('ends the fold at the end of the previous line', async () => {
        const grammar = new TreeSitterGrammar(
          atom.grammars,
          pythonGrammarPath,
          {
            parser: 'tree-sitter-python',
            folds: [
              {
                type: 'function_definition',
                start: { type: ':' }
              }
            ]
          }
        );

        buffer.setText(dedent`
          def ab():
            print 'a'
            print 'b'

          def cd():
            print 'c'
            print 'd'
        `);

        buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));

        editor.foldBufferRow(0);
        expect(getDisplayText(editor)).toBe(dedent`
          def ab():…

          def cd():
            print 'c'
            print 'd'
        `);
      });
    });

    it('folds code in injected languages', async () => {
      const htmlGrammar = new TreeSitterGrammar(
        atom.grammars,
        htmlGrammarPath,
        {
          scopeName: 'html',
          parser: 'tree-sitter-html',
          scopes: {},
          folds: [
            {
              type: ['element', 'raw_element'],
              start: { index: 0 },
              end: { index: -1 }
            }
          ],
          injectionRegExp: 'html'
        }
      );

      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'javascript',
        parser: 'tree-sitter-javascript',
        scopes: {},
        folds: [
          {
            type: ['template_string'],
            start: { index: 0 },
            end: { index: -1 }
          },
          {
            start: { index: 0, type: '(' },
            end: { index: -1, type: ')' }
          }
        ],
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      });

      atom.grammars.addGrammar(htmlGrammar);

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
      );
      const languageMode = new TreeSitterLanguageMode({
        buffer,
        grammar: jsGrammar,
        grammars: atom.grammars
      });
      buffer.setLanguageMode(languageMode);

      editor.foldBufferRow(2);
      expect(getDisplayText(editor)).toBe(
        `a = html \`
            <div>
              c\${def(…
              )}e\${f}g
            </div>
          \`
        `
      );

      editor.foldBufferRow(1);
      expect(getDisplayText(editor)).toBe(
        `a = html \`
            <div>…
            </div>
          \`
        `
      );

      editor.foldBufferRow(0);
      expect(getDisplayText(editor)).toBe(
        `a = html \`…\`
        `
      );
    });
  });

  describe('.scopeDescriptorForPosition', () => {
    it('returns a scope descriptor representing the given position in the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source.js',
          property_identifier: 'property.name',
          comment: 'comment.block'
        }
      });

      buffer.setText('foo({bar: baz});');

      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor
          .scopeDescriptorForBufferPosition([0, 'foo({b'.length])
          .getScopesArray()
      ).toEqual(['source.js', 'property.name']);
      expect(
        editor
          .scopeDescriptorForBufferPosition([0, 'foo({'.length])
          .getScopesArray()
      ).toEqual(['source.js', 'property.name']);

      // Drive-by test for .tokenForPosition()
      const token = editor.tokenForBufferPosition([0, 'foo({b'.length]);
      expect(token.value).toBe('bar');
      expect(token.scopes).toEqual(['source.js', 'property.name']);

      buffer.setText('// baz\n');

      // Adjust position when at end of line
      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor
          .scopeDescriptorForBufferPosition([0, '// baz'.length])
          .getScopesArray()
      ).toEqual(['source.js', 'comment.block']);
    });

    it('includes nodes in injected syntax trees', async () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source.js',
          template_string: 'string.quoted',
          interpolation: 'meta.embedded',
          property_identifier: 'property.name'
        },
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      });

      const htmlGrammar = new TreeSitterGrammar(
        atom.grammars,
        htmlGrammarPath,
        {
          scopeName: 'text.html',
          parser: 'tree-sitter-html',
          scopes: {
            fragment: 'text.html',
            raw_element: 'script.tag'
          },
          injectionRegExp: 'html',
          injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
        }
      );

      atom.grammars.addGrammar(jsGrammar);
      atom.grammars.addGrammar(htmlGrammar);

      buffer.setText(`
        <div>
          <script>
            html \`
              <span>\${person.name}</span>
            \`
          </script>
        </div>
      `);

      const languageMode = new TreeSitterLanguageMode({
        buffer,
        grammar: htmlGrammar,
        grammars: atom.grammars
      });
      buffer.setLanguageMode(languageMode);

      const position = buffer.findSync('name').start;
      expect(
        languageMode.scopeDescriptorForPosition(position).getScopesArray()
      ).toEqual([
        'text.html',
        'script.tag',
        'source.js',
        'string.quoted',
        'text.html',
        'property.name'
      ]);
    });

    it('includes the root scope name even when the given position is in trailing whitespace at EOF', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source.js',
          property_identifier: 'property.name'
        }
      });

      buffer.setText('a; ');
      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor.scopeDescriptorForBufferPosition([0, 3]).getScopesArray()
      ).toEqual(['source.js']);
    });

    it('works when the given position is between tokens', () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript',
        scopes: {
          program: 'source.js',
          comment: 'comment.block'
        }
      });

      buffer.setText('a  // b');
      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor.scopeDescriptorForBufferPosition([0, 2]).getScopesArray()
      ).toEqual(['source.js']);
      expect(
        editor.scopeDescriptorForBufferPosition([0, 3]).getScopesArray()
      ).toEqual(['source.js', 'comment.block']);
    });
  });

  describe('.syntaxTreeScopeDescriptorForPosition', () => {
    it('returns a scope descriptor representing the given position in the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript'
      });

      buffer.setText('foo({bar: baz});');

      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor
          .syntaxTreeScopeDescriptorForBufferPosition([0, 6])
          .getScopesArray()
      ).toEqual([
        'source.js',
        'program',
        'expression_statement',
        'call_expression',
        'arguments',
        'object',
        'pair',
        'property_identifier'
      ]);

      buffer.setText('//bar\n');

      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
      expect(
        editor
          .syntaxTreeScopeDescriptorForBufferPosition([0, 5])
          .getScopesArray()
      ).toEqual(['source.js', 'program', 'comment']);
    });

    it('includes nodes in injected syntax trees', async () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'source.js',
        parser: 'tree-sitter-javascript',
        scopes: {},
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      });

      const htmlGrammar = new TreeSitterGrammar(
        atom.grammars,
        htmlGrammarPath,
        {
          scopeName: 'text.html',
          parser: 'tree-sitter-html',
          scopes: {},
          injectionRegExp: 'html',
          injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
        }
      );

      atom.grammars.addGrammar(jsGrammar);
      atom.grammars.addGrammar(htmlGrammar);

      buffer.setText(`
        <div>
          <script>
            html \`
              <span>\${person.name}</span>
            \`
          </script>
        </div>
      `);

      const languageMode = new TreeSitterLanguageMode({
        buffer,
        grammar: htmlGrammar,
        grammars: atom.grammars
      });
      buffer.setLanguageMode(languageMode);

      const position = buffer.findSync('name').start;
      expect(
        editor
          .syntaxTreeScopeDescriptorForBufferPosition(position)
          .getScopesArray()
      ).toEqual([
        'text.html',
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
      ]);
    });
  });

  describe('.bufferRangeForScopeAtPosition(selector?, position)', () => {
    describe('when selector = null', () => {
      it('returns the range of the smallest node at position', async () => {
        const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript'
        });

        buffer.setText('foo({bar: baz});');

        buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
        expect(editor.bufferRangeForScopeAtPosition(null, [0, 6])).toEqual([
          [0, 5],
          [0, 8]
        ]);
        expect(editor.bufferRangeForScopeAtPosition(null, [0, 9])).toEqual([
          [0, 8],
          [0, 9]
        ]);
      });

      it('includes nodes in injected syntax trees', async () => {
        const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {},
          injectionRegExp: 'javascript',
          injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
        });

        const htmlGrammar = new TreeSitterGrammar(
          atom.grammars,
          htmlGrammarPath,
          {
            scopeName: 'html',
            parser: 'tree-sitter-html',
            scopes: {},
            injectionRegExp: 'html',
            injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
          }
        );

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);

        buffer.setText(`
          <div>
            <script>
              html \`
                <span>\${person.name}</span>
              \`
            </script>
          </div>
        `);

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: htmlGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        const nameProperty = buffer.findSync('name');
        const { start } = nameProperty;
        const position = Object.assign({}, start, { column: start.column + 2 });
        expect(
          languageMode.bufferRangeForScopeAtPosition(null, position)
        ).toEqual(nameProperty);
      });
    });

    describe('with a selector', () => {
      it('returns the range of the smallest matching node at position', async () => {
        const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {
            property_identifier: 'variable.other.object.property',
            template_string: 'string.quoted.template'
          }
        });

        buffer.setText('a(`${b({ccc: ddd})} eee`);');

        buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));
        expect(
          editor.bufferRangeForScopeAtPosition('.variable.property', [0, 9])
        ).toEqual([[0, 8], [0, 11]]);
        expect(
          editor.bufferRangeForScopeAtPosition('.string.quoted', [0, 6])
        ).toEqual([[0, 2], [0, 24]]);
      });

      it('includes nodes in injected syntax trees', async () => {
        const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {
            property_identifier: 'variable.other.object.property'
          },
          injectionRegExp: 'javascript',
          injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
        });

        const htmlGrammar = new TreeSitterGrammar(
          atom.grammars,
          htmlGrammarPath,
          {
            scopeName: 'html',
            parser: 'tree-sitter-html',
            scopes: {
              element: 'meta.element.html'
            },
            injectionRegExp: 'html',
            injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
          }
        );

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);

        buffer.setText(`
          <div>
            <script>
              html \`
                <span>\${person.name}</span>
              \`
            </script>
          </div>
        `);

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: htmlGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        const nameProperty = buffer.findSync('name');
        const { start } = nameProperty;
        const position = Object.assign({}, start, { column: start.column + 2 });
        expect(
          languageMode.bufferRangeForScopeAtPosition(
            '.object.property',
            position
          )
        ).toEqual(nameProperty);
        expect(
          languageMode.bufferRangeForScopeAtPosition(
            '.meta.element.html',
            position
          )
        ).toEqual(buffer.findSync('<span>\\${person\\.name}</span>'));
      });

      it('accepts node-matching functions as selectors', async () => {
        const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
          scopeName: 'javascript',
          parser: 'tree-sitter-javascript',
          scopes: {},
          injectionRegExp: 'javascript',
          injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
        });

        const htmlGrammar = new TreeSitterGrammar(
          atom.grammars,
          htmlGrammarPath,
          {
            scopeName: 'html',
            parser: 'tree-sitter-html',
            scopes: {},
            injectionRegExp: 'html',
            injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
          }
        );

        atom.grammars.addGrammar(jsGrammar);
        atom.grammars.addGrammar(htmlGrammar);

        buffer.setText(`
          <div>
            <script>
              html \`
                <span>\${person.name}</span>
              \`
            </script>
          </div>
        `);

        const languageMode = new TreeSitterLanguageMode({
          buffer,
          grammar: htmlGrammar,
          grammars: atom.grammars
        });
        buffer.setLanguageMode(languageMode);

        const nameProperty = buffer.findSync('name');
        const { start } = nameProperty;
        const position = Object.assign({}, start, { column: start.column + 2 });
        const templateStringInCallExpression = node =>
          node.type === 'template_string' &&
          node.parent.type === 'call_expression';
        expect(
          languageMode.bufferRangeForScopeAtPosition(
            templateStringInCallExpression,
            position
          )
        ).toEqual([[3, 19], [5, 15]]);
      });
    });
  });

  describe('.getSyntaxNodeAtPosition(position, where?)', () => {
    it('returns the range of the smallest matching node at position', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'javascript',
        parser: 'tree-sitter-javascript'
      });

      buffer.setText('foo(bar({x: 2}));');
      const languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      buffer.setLanguageMode(languageMode);
      expect(languageMode.getSyntaxNodeAtPosition([0, 6]).range).toEqual(
        buffer.findSync('bar')
      );
      const findFoo = node =>
        node.type === 'call_expression' && node.firstChild.text === 'foo';
      expect(
        languageMode.getSyntaxNodeAtPosition([0, 6], findFoo).range
      ).toEqual([[0, 0], [0, buffer.getText().length - 1]]);
    });
  });

  describe('.commentStringsForPosition(position)', () => {
    it('returns the correct comment strings for nested languages', () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'javascript',
        parser: 'tree-sitter-javascript',
        comments: { start: '//' },
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      });

      const htmlGrammar = new TreeSitterGrammar(
        atom.grammars,
        htmlGrammarPath,
        {
          scopeName: 'html',
          parser: 'tree-sitter-html',
          scopes: {},
          comments: { start: '<!--', end: '-->' },
          injectionRegExp: 'html',
          injectionPoints: [SCRIPT_TAG_INJECTION_POINT]
        }
      );

      atom.grammars.addGrammar(jsGrammar);
      atom.grammars.addGrammar(htmlGrammar);

      const languageMode = new TreeSitterLanguageMode({
        buffer,
        grammar: htmlGrammar,
        grammars: atom.grammars
      });
      buffer.setLanguageMode(languageMode);
      buffer.setText(
        `
        <div>hi</div>
        <script>
          const node = document.getElementById('some-id');
          node.innerHTML = html \`
            <span>bye</span>
          \`
        </script>
      `.trim()
      );

      const htmlCommentStrings = {
        commentStartString: '<!--',
        commentEndString: '-->'
      };
      const jsCommentStrings = {
        commentStartString: '//',
        commentEndString: undefined
      };

      expect(languageMode.commentStringsForPosition(new Point(0, 0))).toEqual(
        htmlCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(1, 0))).toEqual(
        htmlCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(2, 0))).toEqual(
        jsCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(3, 0))).toEqual(
        jsCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(4, 0))).toEqual(
        htmlCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(5, 0))).toEqual(
        jsCommentStrings
      );
      expect(languageMode.commentStringsForPosition(new Point(6, 0))).toEqual(
        htmlCommentStrings
      );
    });
  });

  describe('TextEditor.selectLargerSyntaxNode and .selectSmallerSyntaxNode', () => {
    it('expands and contracts the selection based on the syntax tree', async () => {
      const grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        parser: 'tree-sitter-javascript',
        scopes: { program: 'source' }
      });

      buffer.setText(dedent`
        function a (b, c, d) {
          eee.f()
          g()
        }
      `);

      buffer.setLanguageMode(new TreeSitterLanguageMode({ buffer, grammar }));

      editor.setCursorBufferPosition([1, 3]);
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee.f');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee.f()');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('{\n  eee.f()\n  g()\n}');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe(
        'function a (b, c, d) {\n  eee.f()\n  g()\n}'
      );

      editor.selectSmallerSyntaxNode();
      expect(editor.getSelectedText()).toBe('{\n  eee.f()\n  g()\n}');
      editor.selectSmallerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee.f()');
      editor.selectSmallerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee.f');
      editor.selectSmallerSyntaxNode();
      expect(editor.getSelectedText()).toBe('eee');
      editor.selectSmallerSyntaxNode();
      expect(editor.getSelectedBufferRange()).toEqual([[1, 3], [1, 3]]);
    });

    it('handles injected languages', async () => {
      const jsGrammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
        scopeName: 'javascript',
        parser: 'tree-sitter-javascript',
        scopes: {
          property_identifier: 'property',
          'call_expression > identifier': 'function',
          template_string: 'string',
          'template_substitution > "${"': 'interpolation',
          'template_substitution > "}"': 'interpolation'
        },
        injectionRegExp: 'javascript',
        injectionPoints: [HTML_TEMPLATE_LITERAL_INJECTION_POINT]
      });

      const htmlGrammar = new TreeSitterGrammar(
        atom.grammars,
        htmlGrammarPath,
        {
          scopeName: 'html',
          parser: 'tree-sitter-html',
          scopes: {
            fragment: 'html',
            tag_name: 'tag',
            attribute_name: 'attr'
          },
          injectionRegExp: 'html'
        }
      );

      atom.grammars.addGrammar(htmlGrammar);

      buffer.setText('a = html ` <b>c${def()}e${f}g</b> `');
      const languageMode = new TreeSitterLanguageMode({
        buffer,
        grammar: jsGrammar,
        grammars: atom.grammars
      });
      buffer.setLanguageMode(languageMode);

      editor.setCursorBufferPosition({
        row: 0,
        column: buffer.getText().indexOf('ef()')
      });
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('def');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('def()');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('${def()}');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('c${def()}e${f}g');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('<b>c${def()}e${f}g</b>');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe(' <b>c${def()}e${f}g</b> ');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('` <b>c${def()}e${f}g</b> `');
      editor.selectLargerSyntaxNode();
      expect(editor.getSelectedText()).toBe('html ` <b>c${def()}e${f}g</b> `');
    });
  });
});

function nextHighlightingUpdate(languageMode) {
  return new Promise(resolve => {
    const subscription = languageMode.onDidChangeHighlighting(() => {
      subscription.dispose();
      resolve();
    });
  });
}

function getDisplayText(editor) {
  return editor.displayLayer.getText();
}

function expectTokensToEqual(editor, expectedTokenLines) {
  const lastRow = editor.getLastScreenRow();

  // Assert that the correct tokens are returned regardless of which row
  // the highlighting iterator starts on.
  for (let startRow = 0; startRow <= lastRow; startRow++) {
    // Clear the screen line cache between iterations, but not on the first
    // iteration, so that the first iteration tests that the cache has been
    // correctly invalidated by any changes.
    if (startRow > 0) {
      editor.displayLayer.clearSpatialIndex();
    }

    editor.displayLayer.getScreenLines(startRow, Infinity);

    const tokenLines = [];
    for (let row = startRow; row <= lastRow; row++) {
      tokenLines[row] = editor
        .tokensForScreenRow(row)
        .map(({ text, scopes }) => ({
          text,
          scopes: scopes.map(scope =>
            scope
              .split(' ')
              .map(className => className.replace('syntax--', ''))
              .join(' ')
          )
        }));
    }

    for (let row = startRow; row <= lastRow; row++) {
      const tokenLine = tokenLines[row];
      const expectedTokenLine = expectedTokenLines[row];

      expect(tokenLine.length).toEqual(expectedTokenLine.length);
      for (let i = 0; i < tokenLine.length; i++) {
        expect(tokenLine[i]).toEqual(
          expectedTokenLine[i],
          `Token ${i}, startRow: ${startRow}`
        );
      }
    }
  }

  // Fully populate the screen line cache again so that cache invalidation
  // due to subsequent edits can be tested.
  editor.displayLayer.getScreenLines(0, Infinity);
}

const HTML_TEMPLATE_LITERAL_INJECTION_POINT = {
  type: 'call_expression',
  language(node) {
    if (
      node.lastChild.type === 'template_string' &&
      node.firstChild.type === 'identifier'
    ) {
      return node.firstChild.text;
    }
  },
  content(node) {
    return node.lastChild;
  }
};

const SCRIPT_TAG_INJECTION_POINT = {
  type: 'raw_element',
  language() {
    return 'javascript';
  },
  content(node) {
    return node.child(1);
  }
};
