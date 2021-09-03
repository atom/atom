const NullGrammar = require('../src/null-grammar');
const TextMateLanguageMode = require('../src/text-mate-language-mode');
const TextBuffer = require('text-buffer');
const { Point } = TextBuffer;
const _ = require('underscore-plus');
const dedent = require('dedent');

describe('TextMateLanguageMode', () => {
  let languageMode, buffer, config;

  beforeEach(async () => {
    config = atom.config;
    config.set('core.useTreeSitterParsers', false);
    // enable async tokenization
    TextMateLanguageMode.prototype.chunkSize = 5;
    jasmine.unspy(TextMateLanguageMode.prototype, 'tokenizeInBackground');
    await atom.packages.activatePackage('language-javascript');
  });

  afterEach(() => {
    buffer && buffer.destroy();
    languageMode && languageMode.destroy();
    config.unset('core.useTreeSitterParsers');
  });

  describe('when the editor is constructed with the largeFileMode option set to true', () => {
    it("loads the editor but doesn't tokenize", async () => {
      const line = 'a b c d\n';
      buffer = new TextBuffer(line.repeat(256 * 1024));
      expect(buffer.getText().length).toBe(2 * 1024 * 1024);
      languageMode = new TextMateLanguageMode({
        buffer,
        grammar: atom.grammars.grammarForScopeName('source.js'),
        tabLength: 2
      });
      buffer.setLanguageMode(languageMode);

      expect(languageMode.isRowCommented(0)).toBeFalsy();

      // It treats the entire line as one big token
      let iterator = languageMode.buildHighlightIterator();
      iterator.seek({ row: 0, column: 0 });
      iterator.moveToSuccessor();
      expect(iterator.getPosition()).toEqual({ row: 0, column: 7 });

      buffer.insert([0, 0], 'hey"');
      iterator = languageMode.buildHighlightIterator();
      iterator.seek({ row: 0, column: 0 });
      iterator.moveToSuccessor();
      expect(iterator.getPosition()).toEqual({ row: 0, column: 11 });
    });
  });

  describe('tokenizing', () => {
    describe('when the buffer is destroyed', () => {
      beforeEach(() => {
        buffer = atom.project.bufferForPathSync('sample.js');
        languageMode = new TextMateLanguageMode({
          buffer,
          config,
          grammar: atom.grammars.grammarForScopeName('source.js')
        });
        languageMode.startTokenizing();
      });

      it('stops tokenization', () => {
        languageMode.destroy();
        spyOn(languageMode, 'tokenizeNextChunk');
        advanceClock();
        expect(languageMode.tokenizeNextChunk).not.toHaveBeenCalled();
      });
    });

    describe('when the buffer contains soft-tabs', () => {
      beforeEach(() => {
        buffer = atom.project.bufferForPathSync('sample.js');
        languageMode = new TextMateLanguageMode({
          buffer,
          config,
          grammar: atom.grammars.grammarForScopeName('source.js')
        });
        buffer.setLanguageMode(languageMode);
        languageMode.startTokenizing();
      });

      afterEach(() => {
        languageMode.destroy();
        buffer.release();
      });

      describe('on construction', () =>
        it('tokenizes lines chunk at a time in the background', () => {
          const line0 = languageMode.tokenizedLines[0];
          expect(line0).toBeUndefined();

          const line11 = languageMode.tokenizedLines[11];
          expect(line11).toBeUndefined();

          // tokenize chunk 1
          advanceClock();
          expect(languageMode.tokenizedLines[0].ruleStack != null).toBeTruthy();
          expect(languageMode.tokenizedLines[4].ruleStack != null).toBeTruthy();
          expect(languageMode.tokenizedLines[5]).toBeUndefined();

          // tokenize chunk 2
          advanceClock();
          expect(languageMode.tokenizedLines[5].ruleStack != null).toBeTruthy();
          expect(languageMode.tokenizedLines[9].ruleStack != null).toBeTruthy();
          expect(languageMode.tokenizedLines[10]).toBeUndefined();

          // tokenize last chunk
          advanceClock();
          expect(
            languageMode.tokenizedLines[10].ruleStack != null
          ).toBeTruthy();
          expect(
            languageMode.tokenizedLines[12].ruleStack != null
          ).toBeTruthy();
        }));

      describe('when the buffer is partially tokenized', () => {
        beforeEach(() => {
          // tokenize chunk 1 only
          advanceClock();
        });

        describe('when there is a buffer change inside the tokenized region', () => {
          describe('when lines are added', () => {
            it('pushes the invalid rows down', () => {
              expect(languageMode.firstInvalidRow()).toBe(5);
              buffer.insert([1, 0], '\n\n');
              expect(languageMode.firstInvalidRow()).toBe(7);
            });
          });

          describe('when lines are removed', () => {
            it('pulls the invalid rows up', () => {
              expect(languageMode.firstInvalidRow()).toBe(5);
              buffer.delete([[1, 0], [3, 0]]);
              expect(languageMode.firstInvalidRow()).toBe(2);
            });
          });

          describe('when the change invalidates all the lines before the current invalid region', () => {
            it('retokenizes the invalidated lines and continues into the valid region', () => {
              expect(languageMode.firstInvalidRow()).toBe(5);
              buffer.insert([2, 0], '/*');
              expect(languageMode.firstInvalidRow()).toBe(3);
              advanceClock();
              expect(languageMode.firstInvalidRow()).toBe(8);
            });
          });
        });

        describe('when there is a buffer change surrounding an invalid row', () => {
          it('pushes the invalid row to the end of the change', () => {
            buffer.setTextInRange([[4, 0], [6, 0]], '\n\n\n');
            expect(languageMode.firstInvalidRow()).toBe(8);
          });
        });

        describe('when there is a buffer change inside an invalid region', () => {
          it('does not attempt to tokenize the lines in the change, and preserves the existing invalid row', () => {
            expect(languageMode.firstInvalidRow()).toBe(5);
            buffer.setTextInRange([[6, 0], [7, 0]], '\n\n\n');
            expect(languageMode.tokenizedLines[6]).toBeUndefined();
            expect(languageMode.tokenizedLines[7]).toBeUndefined();
            expect(languageMode.firstInvalidRow()).toBe(5);
          });
        });
      });

      describe('when the buffer is fully tokenized', () => {
        beforeEach(() => fullyTokenize(languageMode));

        describe('when there is a buffer change that is smaller than the chunk size', () => {
          describe('when lines are updated, but none are added or removed', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange([[0, 0], [2, 0]], 'foo()\n7\n');

              expect(languageMode.tokenizedLines[0].tokens[1]).toEqual({
                value: '(',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'meta.arguments.js',
                  'punctuation.definition.arguments.begin.bracket.round.js'
                ]
              });
              expect(languageMode.tokenizedLines[1].tokens[0]).toEqual({
                value: '7',
                scopes: ['source.js', 'constant.numeric.decimal.js']
              });
              // line 2 is unchanged
              expect(languageMode.tokenizedLines[2].tokens[1]).toEqual({
                value: 'if',
                scopes: ['source.js', 'keyword.control.js']
              });
            });

            describe('when the change invalidates the tokenization of subsequent lines', () => {
              it('schedules the invalidated lines to be tokenized in the background', () => {
                buffer.insert([5, 30], '/* */');
                buffer.insert([2, 0], '/*');
                expect(languageMode.tokenizedLines[3].tokens[0].scopes).toEqual(
                  ['source.js']
                );

                advanceClock();
                expect(languageMode.tokenizedLines[3].tokens[0].scopes).toEqual(
                  ['source.js', 'comment.block.js']
                );
                expect(languageMode.tokenizedLines[4].tokens[0].scopes).toEqual(
                  ['source.js', 'comment.block.js']
                );
                expect(languageMode.tokenizedLines[5].tokens[0].scopes).toEqual(
                  ['source.js', 'comment.block.js']
                );
              });
            });

            it('resumes highlighting with the state of the previous line', () => {
              buffer.insert([0, 0], '/*');
              buffer.insert([5, 0], '*/');

              buffer.insert([1, 0], 'var ');
              expect(languageMode.tokenizedLines[1].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
            });
          });

          describe('when lines are both updated and removed', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange([[1, 0], [3, 0]], 'foo()');

              // previous line 0 remains
              expect(languageMode.tokenizedLines[0].tokens[0]).toEqual({
                value: 'var',
                scopes: ['source.js', 'storage.type.var.js']
              });

              // previous line 3 should be combined with input to form line 1
              expect(languageMode.tokenizedLines[1].tokens[0]).toEqual({
                value: 'foo',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'entity.name.function.js'
                ]
              });
              expect(languageMode.tokenizedLines[1].tokens[6]).toEqual({
                value: '=',
                scopes: ['source.js', 'keyword.operator.assignment.js']
              });

              // lines below deleted regions should be shifted upward
              expect(languageMode.tokenizedLines[2].tokens[1]).toEqual({
                value: 'while',
                scopes: ['source.js', 'keyword.control.js']
              });
              expect(languageMode.tokenizedLines[3].tokens[1]).toEqual({
                value: '=',
                scopes: ['source.js', 'keyword.operator.assignment.js']
              });
              expect(languageMode.tokenizedLines[4].tokens[1]).toEqual({
                value: '<',
                scopes: ['source.js', 'keyword.operator.comparison.js']
              });
            });
          });

          describe('when the change invalidates the tokenization of subsequent lines', () => {
            it('schedules the invalidated lines to be tokenized in the background', () => {
              buffer.insert([5, 30], '/* */');
              buffer.setTextInRange([[2, 0], [3, 0]], '/*');
              expect(languageMode.tokenizedLines[2].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js',
                'punctuation.definition.comment.begin.js'
              ]);
              expect(languageMode.tokenizedLines[3].tokens[0].scopes).toEqual([
                'source.js'
              ]);

              advanceClock();
              expect(languageMode.tokenizedLines[3].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[4].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
            });
          });

          describe('when lines are both updated and inserted', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange(
                [[1, 0], [2, 0]],
                'foo()\nbar()\nbaz()\nquux()'
              );

              // previous line 0 remains
              expect(languageMode.tokenizedLines[0].tokens[0]).toEqual({
                value: 'var',
                scopes: ['source.js', 'storage.type.var.js']
              });

              // 3 new lines inserted
              expect(languageMode.tokenizedLines[1].tokens[0]).toEqual({
                value: 'foo',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'entity.name.function.js'
                ]
              });
              expect(languageMode.tokenizedLines[2].tokens[0]).toEqual({
                value: 'bar',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'entity.name.function.js'
                ]
              });
              expect(languageMode.tokenizedLines[3].tokens[0]).toEqual({
                value: 'baz',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'entity.name.function.js'
                ]
              });

              // previous line 2 is joined with quux() on line 4
              expect(languageMode.tokenizedLines[4].tokens[0]).toEqual({
                value: 'quux',
                scopes: [
                  'source.js',
                  'meta.function-call.js',
                  'entity.name.function.js'
                ]
              });
              expect(languageMode.tokenizedLines[4].tokens[4]).toEqual({
                value: 'if',
                scopes: ['source.js', 'keyword.control.js']
              });

              // previous line 3 is pushed down to become line 5
              expect(languageMode.tokenizedLines[5].tokens[3]).toEqual({
                value: '=',
                scopes: ['source.js', 'keyword.operator.assignment.js']
              });
            });
          });

          describe('when the change invalidates the tokenization of subsequent lines', () => {
            it('schedules the invalidated lines to be tokenized in the background', () => {
              buffer.insert([5, 30], '/* */');
              buffer.insert([2, 0], '/*\nabcde\nabcder');
              expect(languageMode.tokenizedLines[2].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js',
                'punctuation.definition.comment.begin.js'
              ]);
              expect(languageMode.tokenizedLines[3].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[4].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[5].tokens[0].scopes).toEqual([
                'source.js'
              ]);

              advanceClock(); // tokenize invalidated lines in background
              expect(languageMode.tokenizedLines[5].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[6].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[7].tokens[0].scopes).toEqual([
                'source.js',
                'comment.block.js'
              ]);
              expect(languageMode.tokenizedLines[8].tokens[0].scopes).not.toBe([
                'source.js',
                'comment.block.js'
              ]);
            });
          });
        });

        describe('when there is an insertion that is larger than the chunk size', () => {
          it('tokenizes the initial chunk synchronously, then tokenizes the remaining lines in the background', () => {
            const commentBlock = _.multiplyString(
              '// a comment\n',
              languageMode.chunkSize + 2
            );
            buffer.insert([0, 0], commentBlock);
            expect(
              languageMode.tokenizedLines[0].ruleStack != null
            ).toBeTruthy();
            expect(
              languageMode.tokenizedLines[4].ruleStack != null
            ).toBeTruthy();
            expect(languageMode.tokenizedLines[5]).toBeUndefined();

            advanceClock();
            expect(
              languageMode.tokenizedLines[5].ruleStack != null
            ).toBeTruthy();
            expect(
              languageMode.tokenizedLines[6].ruleStack != null
            ).toBeTruthy();
          });
        });
      });
    });

    describe('when the buffer contains hard-tabs', () => {
      beforeEach(async () => {
        atom.packages.activatePackage('language-coffee-script');

        buffer = atom.project.bufferForPathSync('sample-with-tabs.coffee');
        languageMode = new TextMateLanguageMode({
          buffer,
          config,
          grammar: atom.grammars.grammarForScopeName('source.coffee')
        });
        languageMode.startTokenizing();
      });

      afterEach(() => {
        languageMode.destroy();
        buffer.release();
      });

      describe('when the buffer is fully tokenized', () => {
        beforeEach(() => fullyTokenize(languageMode));
      });
    });

    describe('when tokenization completes', () => {
      it('emits the `tokenized` event', async () => {
        const editor = await atom.workspace.open('sample.js');

        const tokenizedHandler = jasmine.createSpy('tokenized handler');
        editor.languageMode.onDidTokenize(tokenizedHandler);
        fullyTokenize(editor.getBuffer().getLanguageMode());
        expect(tokenizedHandler.callCount).toBe(1);
      });

      it("doesn't re-emit the `tokenized` event when it is re-tokenized", async () => {
        const editor = await atom.workspace.open('sample.js');
        fullyTokenize(editor.languageMode);

        const tokenizedHandler = jasmine.createSpy('tokenized handler');
        editor.languageMode.onDidTokenize(tokenizedHandler);
        editor.getBuffer().insert([0, 0], "'");
        fullyTokenize(editor.languageMode);
        expect(tokenizedHandler).not.toHaveBeenCalled();
      });
    });

    describe('when the grammar is updated because a grammar it includes is activated', async () => {
      it('re-emits the `tokenized` event', async () => {
        let tokenizationCount = 0;

        const editor = await atom.workspace.open('coffee.coffee');
        editor.onDidTokenize(() => {
          tokenizationCount++;
        });
        fullyTokenize(editor.getBuffer().getLanguageMode());
        tokenizationCount = 0;

        await atom.packages.activatePackage('language-coffee-script');
        fullyTokenize(editor.getBuffer().getLanguageMode());
        expect(tokenizationCount).toBe(1);
      });

      it('retokenizes the buffer', async () => {
        await atom.packages.activatePackage('language-ruby-on-rails');
        await atom.packages.activatePackage('language-ruby');

        buffer = atom.project.bufferForPathSync();
        buffer.setText("<div class='name'><%= User.find(2).full_name %></div>");

        languageMode = new TextMateLanguageMode({
          buffer,
          config,
          grammar: atom.grammars.selectGrammar('test.erb')
        });
        fullyTokenize(languageMode);
        expect(languageMode.tokenizedLines[0].tokens[0]).toEqual({
          value: "<div class='name'>",
          scopes: ['text.html.ruby']
        });

        await atom.packages.activatePackage('language-html');
        fullyTokenize(languageMode);
        expect(languageMode.tokenizedLines[0].tokens[0]).toEqual({
          value: '<',
          scopes: [
            'text.html.ruby',
            'meta.tag.block.div.html',
            'punctuation.definition.tag.begin.html'
          ]
        });
      });
    });

    describe('when the buffer is configured with the null grammar', () => {
      it('does not actually tokenize using the grammar', () => {
        spyOn(NullGrammar, 'tokenizeLine').andCallThrough();
        buffer = atom.project.bufferForPathSync(
          'sample.will-use-the-null-grammar'
        );
        buffer.setText('a\nb\nc');
        languageMode = new TextMateLanguageMode({ buffer, config });
        const tokenizeCallback = jasmine.createSpy('onDidTokenize');
        languageMode.onDidTokenize(tokenizeCallback);

        expect(languageMode.tokenizedLines[0]).toBeUndefined();
        expect(languageMode.tokenizedLines[1]).toBeUndefined();
        expect(languageMode.tokenizedLines[2]).toBeUndefined();
        expect(tokenizeCallback.callCount).toBe(0);
        expect(NullGrammar.tokenizeLine).not.toHaveBeenCalled();

        fullyTokenize(languageMode);
        expect(languageMode.tokenizedLines[0]).toBeUndefined();
        expect(languageMode.tokenizedLines[1]).toBeUndefined();
        expect(languageMode.tokenizedLines[2]).toBeUndefined();
        expect(tokenizeCallback.callCount).toBe(0);
        expect(NullGrammar.tokenizeLine).not.toHaveBeenCalled();
      });
    });
  });

  describe('.tokenForPosition(position)', () => {
    afterEach(() => {
      languageMode.destroy();
      buffer.release();
    });

    it('returns the correct token (regression)', () => {
      buffer = atom.project.bufferForPathSync('sample.js');
      languageMode = new TextMateLanguageMode({
        buffer,
        config,
        grammar: atom.grammars.grammarForScopeName('source.js')
      });
      fullyTokenize(languageMode);
      expect(languageMode.tokenForPosition([1, 0]).scopes).toEqual([
        'source.js'
      ]);
      expect(languageMode.tokenForPosition([1, 1]).scopes).toEqual([
        'source.js'
      ]);
      expect(languageMode.tokenForPosition([1, 2]).scopes).toEqual([
        'source.js',
        'storage.type.var.js'
      ]);
    });
  });

  describe('.bufferRangeForScopeAtPosition(selector, position)', () => {
    beforeEach(() => {
      buffer = atom.project.bufferForPathSync('sample.js');
      languageMode = new TextMateLanguageMode({
        buffer,
        config,
        grammar: atom.grammars.grammarForScopeName('source.js')
      });
      fullyTokenize(languageMode);
    });

    describe('when the selector does not match the token at the position', () =>
      it('returns a falsy value', () =>
        expect(
          languageMode.bufferRangeForScopeAtPosition('.bogus', [0, 1])
        ).toBeUndefined()));

    describe('when the selector matches a single token at the position', () => {
      it('returns the range covered by the token', () => {
        expect(
          languageMode.bufferRangeForScopeAtPosition('.storage.type.var.js', [
            0,
            1
          ])
        ).toEqual([[0, 0], [0, 3]]);
        expect(
          languageMode.bufferRangeForScopeAtPosition('.storage.type.var.js', [
            0,
            3
          ])
        ).toEqual([[0, 0], [0, 3]]);
      });
    });

    describe('when the selector matches a run of multiple tokens at the position', () => {
      it('returns the range covered by all contiguous tokens (within a single line)', () => {
        expect(
          languageMode.bufferRangeForScopeAtPosition('.function', [1, 18])
        ).toEqual([[1, 6], [1, 28]]);
      });
    });
  });

  describe('.tokenizedLineForRow(row)', () => {
    it("returns the tokenized line for a row, or a placeholder line if it hasn't been tokenized yet", () => {
      buffer = atom.project.bufferForPathSync('sample.js');
      const grammar = atom.grammars.grammarForScopeName('source.js');
      languageMode = new TextMateLanguageMode({ buffer, config, grammar });
      const line0 = buffer.lineForRow(0);

      const jsScopeStartId = grammar.startIdForScope(grammar.scopeName);
      const jsScopeEndId = grammar.endIdForScope(grammar.scopeName);
      languageMode.startTokenizing();
      expect(languageMode.tokenizedLines[0]).toBeUndefined();
      expect(languageMode.tokenizedLineForRow(0).text).toBe(line0);
      expect(languageMode.tokenizedLineForRow(0).tags).toEqual([
        jsScopeStartId,
        line0.length,
        jsScopeEndId
      ]);
      advanceClock(1);
      expect(languageMode.tokenizedLines[0]).not.toBeUndefined();
      expect(languageMode.tokenizedLineForRow(0).text).toBe(line0);
      expect(languageMode.tokenizedLineForRow(0).tags).not.toEqual([
        jsScopeStartId,
        line0.length,
        jsScopeEndId
      ]);
    });

    it('returns undefined if the requested row is outside the buffer range', () => {
      buffer = atom.project.bufferForPathSync('sample.js');
      const grammar = atom.grammars.grammarForScopeName('source.js');
      languageMode = new TextMateLanguageMode({ buffer, config, grammar });
      fullyTokenize(languageMode);
      expect(languageMode.tokenizedLineForRow(999)).toBeUndefined();
    });
  });

  describe('.buildHighlightIterator', () => {
    const { TextMateHighlightIterator } = TextMateLanguageMode;

    it('iterates over the syntactic scope boundaries', () => {
      buffer = new TextBuffer({ text: 'var foo = 1 /*\nhello*/var bar = 2\n' });
      languageMode = new TextMateLanguageMode({
        buffer,
        config,
        grammar: atom.grammars.grammarForScopeName('source.js')
      });
      fullyTokenize(languageMode);

      const iterator = languageMode.buildHighlightIterator();
      iterator.seek(Point(0, 0));

      const expectedBoundaries = [
        {
          position: Point(0, 0),
          closeTags: [],
          openTags: [
            'syntax--source syntax--js',
            'syntax--storage syntax--type syntax--var syntax--js'
          ]
        },
        {
          position: Point(0, 3),
          closeTags: ['syntax--storage syntax--type syntax--var syntax--js'],
          openTags: []
        },
        {
          position: Point(0, 8),
          closeTags: [],
          openTags: [
            'syntax--keyword syntax--operator syntax--assignment syntax--js'
          ]
        },
        {
          position: Point(0, 9),
          closeTags: [
            'syntax--keyword syntax--operator syntax--assignment syntax--js'
          ],
          openTags: []
        },
        {
          position: Point(0, 10),
          closeTags: [],
          openTags: [
            'syntax--constant syntax--numeric syntax--decimal syntax--js'
          ]
        },
        {
          position: Point(0, 11),
          closeTags: [
            'syntax--constant syntax--numeric syntax--decimal syntax--js'
          ],
          openTags: []
        },
        {
          position: Point(0, 12),
          closeTags: [],
          openTags: [
            'syntax--comment syntax--block syntax--js',
            'syntax--punctuation syntax--definition syntax--comment syntax--begin syntax--js'
          ]
        },
        {
          position: Point(0, 14),
          closeTags: [
            'syntax--punctuation syntax--definition syntax--comment syntax--begin syntax--js'
          ],
          openTags: []
        },
        {
          position: Point(1, 5),
          closeTags: [],
          openTags: [
            'syntax--punctuation syntax--definition syntax--comment syntax--end syntax--js'
          ]
        },
        {
          position: Point(1, 7),
          closeTags: [
            'syntax--punctuation syntax--definition syntax--comment syntax--end syntax--js',
            'syntax--comment syntax--block syntax--js'
          ],
          openTags: ['syntax--storage syntax--type syntax--var syntax--js']
        },
        {
          position: Point(1, 10),
          closeTags: ['syntax--storage syntax--type syntax--var syntax--js'],
          openTags: []
        },
        {
          position: Point(1, 15),
          closeTags: [],
          openTags: [
            'syntax--keyword syntax--operator syntax--assignment syntax--js'
          ]
        },
        {
          position: Point(1, 16),
          closeTags: [
            'syntax--keyword syntax--operator syntax--assignment syntax--js'
          ],
          openTags: []
        },
        {
          position: Point(1, 17),
          closeTags: [],
          openTags: [
            'syntax--constant syntax--numeric syntax--decimal syntax--js'
          ]
        },
        {
          position: Point(1, 18),
          closeTags: [
            'syntax--constant syntax--numeric syntax--decimal syntax--js'
          ],
          openTags: []
        }
      ];

      while (true) {
        const boundary = {
          position: iterator.getPosition(),
          closeTags: iterator
            .getCloseScopeIds()
            .map(scopeId => languageMode.classNameForScopeId(scopeId)),
          openTags: iterator
            .getOpenScopeIds()
            .map(scopeId => languageMode.classNameForScopeId(scopeId))
        };

        expect(boundary).toEqual(expectedBoundaries.shift());
        if (!iterator.moveToSuccessor()) {
          break;
        }
      }

      expect(
        iterator
          .seek(Point(0, 1))
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual([
        'syntax--source syntax--js',
        'syntax--storage syntax--type syntax--var syntax--js'
      ]);
      expect(iterator.getPosition()).toEqual(Point(0, 3));
      expect(
        iterator
          .seek(Point(0, 8))
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual(['syntax--source syntax--js']);
      expect(iterator.getPosition()).toEqual(Point(0, 8));
      expect(
        iterator
          .seek(Point(1, 0))
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual([
        'syntax--source syntax--js',
        'syntax--comment syntax--block syntax--js'
      ]);
      expect(iterator.getPosition()).toEqual(Point(1, 0));
      expect(
        iterator
          .seek(Point(1, 18))
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual([
        'syntax--source syntax--js',
        'syntax--constant syntax--numeric syntax--decimal syntax--js'
      ]);
      expect(iterator.getPosition()).toEqual(Point(1, 18));

      expect(
        iterator
          .seek(Point(2, 0))
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual(['syntax--source syntax--js']);
      iterator.moveToSuccessor();
    }); // ensure we don't infinitely loop (regression test)

    it('does not report columns beyond the length of the line', async () => {
      await atom.packages.activatePackage('language-coffee-script');

      buffer = new TextBuffer({ text: '# hello\n# world' });
      languageMode = new TextMateLanguageMode({
        buffer,
        config,
        grammar: atom.grammars.grammarForScopeName('source.coffee')
      });
      fullyTokenize(languageMode);

      const iterator = languageMode.buildHighlightIterator();
      iterator.seek(Point(0, 0));
      iterator.moveToSuccessor();
      iterator.moveToSuccessor();
      expect(iterator.getPosition().column).toBe(7);

      iterator.moveToSuccessor();
      expect(iterator.getPosition().column).toBe(0);

      iterator.seek(Point(0, 7));
      expect(iterator.getPosition().column).toBe(7);

      iterator.seek(Point(0, 8));
      expect(iterator.getPosition().column).toBe(7);
    });

    it('correctly terminates scopes at the beginning of the line (regression)', () => {
      const grammar = atom.grammars.createGrammar('test', {
        scopeName: 'text.broken',
        name: 'Broken grammar',
        patterns: [
          { begin: 'start', end: '(?=end)', name: 'blue.broken' },
          { match: '.', name: 'yellow.broken' }
        ]
      });

      buffer = new TextBuffer({ text: 'start x\nend x\nx' });
      languageMode = new TextMateLanguageMode({ buffer, config, grammar });
      fullyTokenize(languageMode);

      const iterator = languageMode.buildHighlightIterator();
      iterator.seek(Point(1, 0));

      expect(iterator.getPosition()).toEqual([1, 0]);
      expect(
        iterator
          .getCloseScopeIds()
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual(['syntax--blue syntax--broken']);
      expect(
        iterator
          .getOpenScopeIds()
          .map(scopeId => languageMode.classNameForScopeId(scopeId))
      ).toEqual(['syntax--yellow syntax--broken']);
    });

    describe('TextMateHighlightIterator.seek(position)', function() {
      it('seeks to the leftmost tag boundary greater than or equal to the given position and returns the containing tags', function() {
        const languageMode = {
          tokenizedLineForRow(row) {
            if (row === 0) {
              return {
                tags: [-1, -2, -3, -4, -5, 3, -3, -4, -6, -5, 4, -6, -3, -4],
                text: 'foo bar',
                openScopes: []
              };
            } else {
              return null;
            }
          }
        };

        const iterator = new TextMateHighlightIterator(languageMode);

        expect(iterator.seek(Point(0, 0))).toEqual([]);
        expect(iterator.getPosition()).toEqual(Point(0, 0));
        expect(iterator.getCloseScopeIds()).toEqual([]);
        expect(iterator.getOpenScopeIds()).toEqual([257]);

        iterator.moveToSuccessor();
        expect(iterator.getCloseScopeIds()).toEqual([257]);
        expect(iterator.getOpenScopeIds()).toEqual([259]);

        expect(iterator.seek(Point(0, 1))).toEqual([261]);
        expect(iterator.getPosition()).toEqual(Point(0, 3));
        expect(iterator.getCloseScopeIds()).toEqual([]);
        expect(iterator.getOpenScopeIds()).toEqual([259]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 3));
        expect(iterator.getCloseScopeIds()).toEqual([259, 261]);
        expect(iterator.getOpenScopeIds()).toEqual([261]);

        expect(iterator.seek(Point(0, 3))).toEqual([261]);
        expect(iterator.getPosition()).toEqual(Point(0, 3));
        expect(iterator.getCloseScopeIds()).toEqual([]);
        expect(iterator.getOpenScopeIds()).toEqual([259]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 3));
        expect(iterator.getCloseScopeIds()).toEqual([259, 261]);
        expect(iterator.getOpenScopeIds()).toEqual([261]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 7));
        expect(iterator.getCloseScopeIds()).toEqual([261]);
        expect(iterator.getOpenScopeIds()).toEqual([259]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 7));
        expect(iterator.getCloseScopeIds()).toEqual([259]);
        expect(iterator.getOpenScopeIds()).toEqual([]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(1, 0));
        expect(iterator.getCloseScopeIds()).toEqual([]);
        expect(iterator.getOpenScopeIds()).toEqual([]);

        expect(iterator.seek(Point(0, 5))).toEqual([261]);
        expect(iterator.getPosition()).toEqual(Point(0, 7));
        expect(iterator.getCloseScopeIds()).toEqual([261]);
        expect(iterator.getOpenScopeIds()).toEqual([259]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 7));
        expect(iterator.getCloseScopeIds()).toEqual([259]);
        expect(iterator.getOpenScopeIds()).toEqual([]);
      });
    });

    describe('TextMateHighlightIterator.moveToSuccessor()', function() {
      it('reports two boundaries at the same position when tags close, open, then close again without a non-negative integer separating them (regression)', () => {
        const languageMode = {
          tokenizedLineForRow() {
            return {
              tags: [-1, -2, -1, -2],
              text: '',
              openScopes: []
            };
          }
        };

        const iterator = new TextMateHighlightIterator(languageMode);

        iterator.seek(Point(0, 0));
        expect(iterator.getPosition()).toEqual(Point(0, 0));
        expect(iterator.getCloseScopeIds()).toEqual([]);
        expect(iterator.getOpenScopeIds()).toEqual([257]);

        iterator.moveToSuccessor();
        expect(iterator.getPosition()).toEqual(Point(0, 0));
        expect(iterator.getCloseScopeIds()).toEqual([257]);
        expect(iterator.getOpenScopeIds()).toEqual([257]);

        iterator.moveToSuccessor();
        expect(iterator.getCloseScopeIds()).toEqual([257]);
        expect(iterator.getOpenScopeIds()).toEqual([]);
      });
    });
  });

  describe('.suggestedIndentForBufferRow', () => {
    let editor;

    describe('javascript', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('sample.js', { autoIndent: false });
        await atom.packages.activatePackage('language-javascript');
      });

      it('bases indentation off of the previous non-blank line', () => {
        expect(editor.suggestedIndentForBufferRow(0)).toBe(0);
        expect(editor.suggestedIndentForBufferRow(1)).toBe(1);
        expect(editor.suggestedIndentForBufferRow(2)).toBe(2);
        expect(editor.suggestedIndentForBufferRow(5)).toBe(3);
        expect(editor.suggestedIndentForBufferRow(7)).toBe(2);
        expect(editor.suggestedIndentForBufferRow(9)).toBe(1);
        expect(editor.suggestedIndentForBufferRow(11)).toBe(1);
      });

      it('does not take invisibles into account', () => {
        editor.update({ showInvisibles: true });
        expect(editor.suggestedIndentForBufferRow(0)).toBe(0);
        expect(editor.suggestedIndentForBufferRow(1)).toBe(1);
        expect(editor.suggestedIndentForBufferRow(2)).toBe(2);
        expect(editor.suggestedIndentForBufferRow(5)).toBe(3);
        expect(editor.suggestedIndentForBufferRow(7)).toBe(2);
        expect(editor.suggestedIndentForBufferRow(9)).toBe(1);
        expect(editor.suggestedIndentForBufferRow(11)).toBe(1);
      });
    });

    describe('css', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('css.css', { autoIndent: true });
        await atom.packages.activatePackage('language-source');
        await atom.packages.activatePackage('language-css');
      });

      it('does not return negative values (regression)', () => {
        editor.setText('.test {\npadding: 0;\n}');
        expect(editor.suggestedIndentForBufferRow(2)).toBe(0);
      });
    });
  });

  describe('.isFoldableAtRow(row)', () => {
    let editor;

    beforeEach(() => {
      buffer = atom.project.bufferForPathSync('sample.js');
      buffer.insert([10, 0], '  // multi-line\n  // comment\n  // block\n');
      buffer.insert([0, 0], '// multi-line\n// comment\n// block\n');
      languageMode = new TextMateLanguageMode({
        buffer,
        config,
        grammar: atom.grammars.grammarForScopeName('source.js')
      });
      buffer.setLanguageMode(languageMode);
      fullyTokenize(languageMode);
    });

    it('includes the first line of multi-line comments', () => {
      expect(languageMode.isFoldableAtRow(0)).toBe(true);
      expect(languageMode.isFoldableAtRow(1)).toBe(false);
      expect(languageMode.isFoldableAtRow(2)).toBe(false);
      expect(languageMode.isFoldableAtRow(3)).toBe(true); // because of indent
      expect(languageMode.isFoldableAtRow(13)).toBe(true);
      expect(languageMode.isFoldableAtRow(14)).toBe(false);
      expect(languageMode.isFoldableAtRow(15)).toBe(false);
      expect(languageMode.isFoldableAtRow(16)).toBe(false);

      buffer.insert([0, Infinity], '\n');

      expect(languageMode.isFoldableAtRow(0)).toBe(false);
      expect(languageMode.isFoldableAtRow(1)).toBe(false);
      expect(languageMode.isFoldableAtRow(2)).toBe(true);
      expect(languageMode.isFoldableAtRow(3)).toBe(false);

      buffer.undo();

      expect(languageMode.isFoldableAtRow(0)).toBe(true);
      expect(languageMode.isFoldableAtRow(1)).toBe(false);
      expect(languageMode.isFoldableAtRow(2)).toBe(false);
      expect(languageMode.isFoldableAtRow(3)).toBe(true);
    }); // because of indent

    it('includes non-comment lines that precede an increase in indentation', () => {
      buffer.insert([2, 0], '  '); // commented lines preceding an indent aren't foldable

      expect(languageMode.isFoldableAtRow(1)).toBe(false);
      expect(languageMode.isFoldableAtRow(2)).toBe(false);
      expect(languageMode.isFoldableAtRow(3)).toBe(true);
      expect(languageMode.isFoldableAtRow(4)).toBe(true);
      expect(languageMode.isFoldableAtRow(5)).toBe(false);
      expect(languageMode.isFoldableAtRow(6)).toBe(false);
      expect(languageMode.isFoldableAtRow(7)).toBe(true);
      expect(languageMode.isFoldableAtRow(8)).toBe(false);

      buffer.insert([7, 0], '  ');

      expect(languageMode.isFoldableAtRow(6)).toBe(true);
      expect(languageMode.isFoldableAtRow(7)).toBe(false);
      expect(languageMode.isFoldableAtRow(8)).toBe(false);

      buffer.undo();

      expect(languageMode.isFoldableAtRow(6)).toBe(false);
      expect(languageMode.isFoldableAtRow(7)).toBe(true);
      expect(languageMode.isFoldableAtRow(8)).toBe(false);

      buffer.insert([7, 0], '    \n      x\n');

      expect(languageMode.isFoldableAtRow(6)).toBe(true);
      expect(languageMode.isFoldableAtRow(7)).toBe(false);
      expect(languageMode.isFoldableAtRow(8)).toBe(false);

      buffer.insert([9, 0], '  ');

      expect(languageMode.isFoldableAtRow(6)).toBe(true);
      expect(languageMode.isFoldableAtRow(7)).toBe(false);
      expect(languageMode.isFoldableAtRow(8)).toBe(false);
    });

    it('returns true if the line starts a multi-line comment', async () => {
      editor = await atom.workspace.open('sample-with-comments.js');
      fullyTokenize(editor.getBuffer().getLanguageMode());

      expect(editor.isFoldableAtBufferRow(1)).toBe(true);
      expect(editor.isFoldableAtBufferRow(6)).toBe(true);
      expect(editor.isFoldableAtBufferRow(8)).toBe(false);
      expect(editor.isFoldableAtBufferRow(11)).toBe(true);
      expect(editor.isFoldableAtBufferRow(15)).toBe(false);
      expect(editor.isFoldableAtBufferRow(17)).toBe(true);
      expect(editor.isFoldableAtBufferRow(21)).toBe(true);
      expect(editor.isFoldableAtBufferRow(24)).toBe(true);
      expect(editor.isFoldableAtBufferRow(28)).toBe(false);
    });

    it('returns true for lines that end with a comment and are followed by an indented line', async () => {
      editor = await atom.workspace.open('sample-with-comments.js');

      expect(editor.isFoldableAtBufferRow(5)).toBe(true);
    });

    it("does not return true for a line in the middle of a comment that's followed by an indented line", async () => {
      editor = await atom.workspace.open('sample-with-comments.js');
      fullyTokenize(editor.getBuffer().getLanguageMode());

      expect(editor.isFoldableAtBufferRow(7)).toBe(false);
      editor.buffer.insert([8, 0], '  ');
      expect(editor.isFoldableAtBufferRow(7)).toBe(false);
    });
  });

  describe('.getFoldableRangesAtIndentLevel', () => {
    let editor;

    it('returns the ranges that can be folded at the given indent level', () => {
      buffer = new TextBuffer(dedent`
        if (a) {
          b();
          if (c) {
            d()
            if (e) {
              f()
            }
            g()
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);

      languageMode = new TextMateLanguageMode({ buffer, config });

      expect(simulateFold(languageMode.getFoldableRangesAtIndentLevel(0, 2)))
        .toBe(dedent`
        if (a) {⋯
        }
        i()
        if (j) {⋯
        }
      `);

      expect(simulateFold(languageMode.getFoldableRangesAtIndentLevel(1, 2)))
        .toBe(dedent`
        if (a) {
          b();
          if (c) {⋯
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);

      expect(simulateFold(languageMode.getFoldableRangesAtIndentLevel(2, 2)))
        .toBe(dedent`
        if (a) {
          b();
          if (c) {
            d()
            if (e) {⋯
            }
            g()
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);
    });

    it('folds every foldable range at a given indentLevel', async () => {
      editor = await atom.workspace.open('sample-with-comments.js');
      fullyTokenize(editor.getBuffer().getLanguageMode());

      editor.foldAllAtIndentLevel(2);
      const folds = editor.unfoldAll();
      expect(folds.length).toBe(5);
      expect([folds[0].start.row, folds[0].end.row]).toEqual([6, 8]);
      expect([folds[1].start.row, folds[1].end.row]).toEqual([11, 16]);
      expect([folds[2].start.row, folds[2].end.row]).toEqual([17, 20]);
      expect([folds[3].start.row, folds[3].end.row]).toEqual([21, 22]);
      expect([folds[4].start.row, folds[4].end.row]).toEqual([24, 25]);
    });
  });

  describe('.getFoldableRanges', () => {
    it('returns the ranges that can be folded', () => {
      buffer = new TextBuffer(dedent`
        if (a) {
          b();
          if (c) {
            d()
            if (e) {
              f()
            }
            g()
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);

      languageMode = new TextMateLanguageMode({ buffer, config });

      expect(languageMode.getFoldableRanges(2).map(r => r.toString())).toEqual(
        [
          ...languageMode.getFoldableRangesAtIndentLevel(0, 2),
          ...languageMode.getFoldableRangesAtIndentLevel(1, 2),
          ...languageMode.getFoldableRangesAtIndentLevel(2, 2)
        ]
          .sort((a, b) => a.start.row - b.start.row || a.end.row - b.end.row)
          .map(r => r.toString())
      );
    });

    it('works with multi-line comments', async () => {
      await atom.packages.activatePackage('language-javascript');
      const editor = await atom.workspace.open('sample-with-comments.js', {
        autoIndent: false
      });
      fullyTokenize(editor.getBuffer().getLanguageMode());

      editor.foldAll();
      const folds = editor.unfoldAll();
      expect(folds.length).toBe(8);
      expect([folds[0].start.row, folds[0].end.row]).toEqual([0, 30]);
      expect([folds[1].start.row, folds[1].end.row]).toEqual([1, 4]);
      expect([folds[2].start.row, folds[2].end.row]).toEqual([5, 27]);
      expect([folds[3].start.row, folds[3].end.row]).toEqual([6, 8]);
      expect([folds[4].start.row, folds[4].end.row]).toEqual([11, 16]);
      expect([folds[5].start.row, folds[5].end.row]).toEqual([17, 20]);
      expect([folds[6].start.row, folds[6].end.row]).toEqual([21, 22]);
      expect([folds[7].start.row, folds[7].end.row]).toEqual([24, 25]);
    });
  });

  describe('.getFoldableRangeContainingPoint', () => {
    it('returns the range for the smallest fold that contains the given range', () => {
      buffer = new TextBuffer(dedent`
        if (a) {
          b();
          if (c) {
            d()
            if (e) {
              f()
            }
            g()
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);

      languageMode = new TextMateLanguageMode({ buffer, config });

      expect(
        languageMode.getFoldableRangeContainingPoint(Point(0, 5), 2)
      ).toBeNull();

      let range = languageMode.getFoldableRangeContainingPoint(Point(0, 10), 2);
      expect(simulateFold([range])).toBe(dedent`
        if (a) {⋯
        }
        i()
        if (j) {
          k()
        }
      `);

      range = languageMode.getFoldableRangeContainingPoint(Point(7, 0), 2);
      expect(simulateFold([range])).toBe(dedent`
        if (a) {
          b();
          if (c) {⋯
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);

      range = languageMode.getFoldableRangeContainingPoint(
        Point(1, Infinity),
        2
      );
      expect(simulateFold([range])).toBe(dedent`
        if (a) {⋯
        }
        i()
        if (j) {
          k()
        }
      `);

      range = languageMode.getFoldableRangeContainingPoint(Point(2, 20), 2);
      expect(simulateFold([range])).toBe(dedent`
        if (a) {
          b();
          if (c) {⋯
          }
          h()
        }
        i()
        if (j) {
          k()
        }
      `);
    });

    it('works for coffee-script', async () => {
      const editor = await atom.workspace.open('coffee.coffee');
      await atom.packages.activatePackage('language-coffee-script');
      buffer = editor.buffer;
      languageMode = editor.languageMode;

      expect(
        languageMode.getFoldableRangeContainingPoint(Point(0, Infinity), 2)
      ).toEqual([[0, Infinity], [20, Infinity]]);
      expect(
        languageMode.getFoldableRangeContainingPoint(Point(1, Infinity), 2)
      ).toEqual([[1, Infinity], [17, Infinity]]);
      expect(
        languageMode.getFoldableRangeContainingPoint(Point(2, Infinity), 2)
      ).toEqual([[1, Infinity], [17, Infinity]]);
      expect(
        languageMode.getFoldableRangeContainingPoint(Point(19, Infinity), 2)
      ).toEqual([[19, Infinity], [20, Infinity]]);
    });

    it('works for javascript', async () => {
      const editor = await atom.workspace.open('sample.js');
      await atom.packages.activatePackage('language-javascript');
      buffer = editor.buffer;
      languageMode = editor.languageMode;

      expect(
        editor.languageMode.getFoldableRangeContainingPoint(
          Point(0, Infinity),
          2
        )
      ).toEqual([[0, Infinity], [12, Infinity]]);
      expect(
        editor.languageMode.getFoldableRangeContainingPoint(
          Point(1, Infinity),
          2
        )
      ).toEqual([[1, Infinity], [9, Infinity]]);
      expect(
        editor.languageMode.getFoldableRangeContainingPoint(
          Point(2, Infinity),
          2
        )
      ).toEqual([[1, Infinity], [9, Infinity]]);
      expect(
        editor.languageMode.getFoldableRangeContainingPoint(
          Point(4, Infinity),
          2
        )
      ).toEqual([[4, Infinity], [7, Infinity]]);
    });

    it('searches upward and downward for surrounding comment lines and folds them as a single fold', async () => {
      await atom.packages.activatePackage('language-javascript');
      const editor = await atom.workspace.open('sample-with-comments.js');
      editor.buffer.insert(
        [1, 0],
        '  //this is a comment\n  // and\n  //more docs\n\n//second comment'
      );
      fullyTokenize(editor.getBuffer().getLanguageMode());
      editor.foldBufferRow(1);
      const [fold] = editor.unfoldAll();
      expect([fold.start.row, fold.end.row]).toEqual([1, 3]);
    });
  });

  describe('TokenIterator', () =>
    it('correctly terminates scopes at the beginning of the line (regression)', () => {
      const grammar = atom.grammars.createGrammar('test', {
        scopeName: 'text.broken',
        name: 'Broken grammar',
        patterns: [
          {
            begin: 'start',
            end: '(?=end)',
            name: 'blue.broken'
          },
          {
            match: '.',
            name: 'yellow.broken'
          }
        ]
      });

      const buffer = new TextBuffer({
        text: dedent`
        start x
        end x
        x
      `
      });

      const languageMode = new TextMateLanguageMode({
        buffer,
        grammar,
        config: atom.config,
        grammarRegistry: atom.grammars,
        packageManager: atom.packages,
        assert: atom.assert
      });

      fullyTokenize(languageMode);

      const tokenIterator = languageMode
        .tokenizedLineForRow(1)
        .getTokenIterator();
      tokenIterator.next();

      expect(tokenIterator.getBufferStart()).toBe(0);
      expect(tokenIterator.getScopeEnds()).toEqual([]);
      expect(tokenIterator.getScopeStarts()).toEqual([
        'text.broken',
        'yellow.broken'
      ]);
    }));

  function simulateFold(ranges) {
    buffer.transact(() => {
      for (const range of ranges.reverse()) {
        buffer.setTextInRange(range, '⋯');
      }
    });
    let text = buffer.getText();
    buffer.undo();
    return text;
  }

  function fullyTokenize(languageMode) {
    languageMode.startTokenizing();
    while (languageMode.firstInvalidRow() != null) {
      advanceClock();
    }
  }
});
