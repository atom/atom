const NullGrammar = require('../src/null-grammar')
const TokenizedBuffer = require('../src/tokenized-buffer')
const TextBuffer = require('text-buffer')
const {Point, Range} = TextBuffer
const _ = require('underscore-plus')
const dedent = require('dedent')
const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')
const {ScopedSettingsDelegate} = require('../src/text-editor-registry')

describe('TokenizedBuffer', () => {
  let tokenizedBuffer, buffer

  beforeEach(async () => {
    // enable async tokenization
    TokenizedBuffer.prototype.chunkSize = 5
    jasmine.unspy(TokenizedBuffer.prototype, 'tokenizeInBackground')
    await atom.packages.activatePackage('language-javascript')
  })

  afterEach(() => {
    buffer && buffer.destroy()
    tokenizedBuffer && tokenizedBuffer.destroy()
  })

  function startTokenizing (tokenizedBuffer) {
    tokenizedBuffer.setVisible(true)
  }

  function fullyTokenize (tokenizedBuffer) {
    tokenizedBuffer.setVisible(true)
    while (tokenizedBuffer.firstInvalidRow() != null) {
      advanceClock()
    }
  }

  describe('serialization', () => {
    describe('when the underlying buffer has a path', () => {
      beforeEach(async () => {
        buffer = atom.project.bufferForPathSync('sample.js')
        await atom.packages.activatePackage('language-coffee-script')
      })

      it('deserializes it searching among the buffers in the current project', () => {
        const tokenizedBufferA = new TokenizedBuffer({buffer, tabLength: 2})
        const tokenizedBufferB = TokenizedBuffer.deserialize(JSON.parse(JSON.stringify(tokenizedBufferA.serialize())), atom)
        expect(tokenizedBufferB.buffer).toBe(tokenizedBufferA.buffer)
      })
    })

    describe('when the underlying buffer has no path', () => {
      beforeEach(() => buffer = atom.project.bufferForPathSync(null))

      it('deserializes it searching among the buffers in the current project', () => {
        const tokenizedBufferA = new TokenizedBuffer({buffer, tabLength: 2})
        const tokenizedBufferB = TokenizedBuffer.deserialize(JSON.parse(JSON.stringify(tokenizedBufferA.serialize())), atom)
        expect(tokenizedBufferB.buffer).toBe(tokenizedBufferA.buffer)
      })
    })
  })

  describe('tokenizing', () => {
    describe('when the buffer is destroyed', () => {
      beforeEach(() => {
        buffer = atom.project.bufferForPathSync('sample.js')
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
        startTokenizing(tokenizedBuffer)
      })

      it('stops tokenization', () => {
        tokenizedBuffer.destroy()
        spyOn(tokenizedBuffer, 'tokenizeNextChunk')
        advanceClock()
        expect(tokenizedBuffer.tokenizeNextChunk).not.toHaveBeenCalled()
      })
    })

    describe('when the buffer contains soft-tabs', () => {
      beforeEach(() => {
        buffer = atom.project.bufferForPathSync('sample.js')
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
        startTokenizing(tokenizedBuffer)
      })

      afterEach(() => {
        tokenizedBuffer.destroy()
        buffer.release()
      })

      describe('on construction', () =>
        it('tokenizes lines chunk at a time in the background', () => {
          const line0 = tokenizedBuffer.tokenizedLines[0]
          expect(line0).toBeUndefined()

          const line11 = tokenizedBuffer.tokenizedLines[11]
          expect(line11).toBeUndefined()

          // tokenize chunk 1
          advanceClock()
          expect(tokenizedBuffer.tokenizedLines[0].ruleStack != null).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLines[4].ruleStack != null).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLines[5]).toBeUndefined()

          // tokenize chunk 2
          advanceClock()
          expect(tokenizedBuffer.tokenizedLines[5].ruleStack != null).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLines[9].ruleStack != null).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLines[10]).toBeUndefined()

          // tokenize last chunk
          advanceClock()
          expect(tokenizedBuffer.tokenizedLines[10].ruleStack != null).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLines[12].ruleStack != null).toBeTruthy()
        })
      )

      describe('when the buffer is partially tokenized', () => {
        beforeEach(() => {
          // tokenize chunk 1 only
          advanceClock()
        })

        describe('when there is a buffer change inside the tokenized region', () => {
          describe('when lines are added', () => {
            it('pushes the invalid rows down', () => {
              expect(tokenizedBuffer.firstInvalidRow()).toBe(5)
              buffer.insert([1, 0], '\n\n')
              expect(tokenizedBuffer.firstInvalidRow()).toBe(7)
            })
          })

          describe('when lines are removed', () => {
            it('pulls the invalid rows up', () => {
              expect(tokenizedBuffer.firstInvalidRow()).toBe(5)
              buffer.delete([[1, 0], [3, 0]])
              expect(tokenizedBuffer.firstInvalidRow()).toBe(2)
            })
          })

          describe('when the change invalidates all the lines before the current invalid region', () => {
            it('retokenizes the invalidated lines and continues into the valid region', () => {
              expect(tokenizedBuffer.firstInvalidRow()).toBe(5)
              buffer.insert([2, 0], '/*')
              expect(tokenizedBuffer.firstInvalidRow()).toBe(3)
              advanceClock()
              expect(tokenizedBuffer.firstInvalidRow()).toBe(8)
            })
          })
        })

        describe('when there is a buffer change surrounding an invalid row', () => {
          it('pushes the invalid row to the end of the change', () => {
            buffer.setTextInRange([[4, 0], [6, 0]], '\n\n\n')
            expect(tokenizedBuffer.firstInvalidRow()).toBe(8)
          })
        })

        describe('when there is a buffer change inside an invalid region', () => {
          it('does not attempt to tokenize the lines in the change, and preserves the existing invalid row', () => {
            expect(tokenizedBuffer.firstInvalidRow()).toBe(5)
            buffer.setTextInRange([[6, 0], [7, 0]], '\n\n\n')
            expect(tokenizedBuffer.tokenizedLines[6]).toBeUndefined()
            expect(tokenizedBuffer.tokenizedLines[7]).toBeUndefined()
            expect(tokenizedBuffer.firstInvalidRow()).toBe(5)
          })
        })
      })

      describe('when the buffer is fully tokenized', () => {
        beforeEach(() => fullyTokenize(tokenizedBuffer))

        describe('when there is a buffer change that is smaller than the chunk size', () => {
          describe('when lines are updated, but none are added or removed', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange([[0, 0], [2, 0]], 'foo()\n7\n')

              expect(tokenizedBuffer.tokenizedLines[0].tokens[1]).toEqual({value: '(', scopes: ['source.js', 'meta.function-call.js', 'meta.arguments.js', 'punctuation.definition.arguments.begin.bracket.round.js']})
              expect(tokenizedBuffer.tokenizedLines[1].tokens[0]).toEqual({value: '7', scopes: ['source.js', 'constant.numeric.decimal.js']})
              // line 2 is unchanged
              expect(tokenizedBuffer.tokenizedLines[2].tokens[1]).toEqual({value: 'if', scopes: ['source.js', 'keyword.control.js']})
            })

            describe('when the change invalidates the tokenization of subsequent lines', () => {
              it('schedules the invalidated lines to be tokenized in the background', () => {
                buffer.insert([5, 30], '/* */')
                buffer.insert([2, 0], '/*')
                expect(tokenizedBuffer.tokenizedLines[3].tokens[0].scopes).toEqual(['source.js'])

                advanceClock()
                expect(tokenizedBuffer.tokenizedLines[3].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
                expect(tokenizedBuffer.tokenizedLines[4].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
                expect(tokenizedBuffer.tokenizedLines[5].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              })
            })

            it('resumes highlighting with the state of the previous line', () => {
              buffer.insert([0, 0], '/*')
              buffer.insert([5, 0], '*/')

              buffer.insert([1, 0], 'var ')
              expect(tokenizedBuffer.tokenizedLines[1].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
            })
          })

          describe('when lines are both updated and removed', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange([[1, 0], [3, 0]], 'foo()')

              // previous line 0 remains
              expect(tokenizedBuffer.tokenizedLines[0].tokens[0]).toEqual({value: 'var', scopes: ['source.js', 'storage.type.var.js']})

              // previous line 3 should be combined with input to form line 1
              expect(tokenizedBuffer.tokenizedLines[1].tokens[0]).toEqual({value: 'foo', scopes: ['source.js', 'meta.function-call.js', 'entity.name.function.js']})
              expect(tokenizedBuffer.tokenizedLines[1].tokens[6]).toEqual({value: '=', scopes: ['source.js', 'keyword.operator.assignment.js']})

              // lines below deleted regions should be shifted upward
              expect(tokenizedBuffer.tokenizedLines[2].tokens[1]).toEqual({value: 'while', scopes: ['source.js', 'keyword.control.js']})
              expect(tokenizedBuffer.tokenizedLines[3].tokens[1]).toEqual({value: '=', scopes: ['source.js', 'keyword.operator.assignment.js']})
              expect(tokenizedBuffer.tokenizedLines[4].tokens[1]).toEqual({value: '<', scopes: ['source.js', 'keyword.operator.comparison.js']})
            })
          })

          describe('when the change invalidates the tokenization of subsequent lines', () => {
            it('schedules the invalidated lines to be tokenized in the background', () => {
              buffer.insert([5, 30], '/* */')
              buffer.setTextInRange([[2, 0], [3, 0]], '/*')
              expect(tokenizedBuffer.tokenizedLines[2].tokens[0].scopes).toEqual(['source.js', 'comment.block.js', 'punctuation.definition.comment.begin.js'])
              expect(tokenizedBuffer.tokenizedLines[3].tokens[0].scopes).toEqual(['source.js'])

              advanceClock()
              expect(tokenizedBuffer.tokenizedLines[3].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[4].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
            })
          })

          describe('when lines are both updated and inserted', () => {
            it('updates tokens to reflect the change', () => {
              buffer.setTextInRange([[1, 0], [2, 0]], 'foo()\nbar()\nbaz()\nquux()')

              // previous line 0 remains
              expect(tokenizedBuffer.tokenizedLines[0].tokens[0]).toEqual({ value: 'var', scopes: ['source.js', 'storage.type.var.js']})

              // 3 new lines inserted
              expect(tokenizedBuffer.tokenizedLines[1].tokens[0]).toEqual({value: 'foo', scopes: ['source.js', 'meta.function-call.js', 'entity.name.function.js']})
              expect(tokenizedBuffer.tokenizedLines[2].tokens[0]).toEqual({value: 'bar', scopes: ['source.js', 'meta.function-call.js', 'entity.name.function.js']})
              expect(tokenizedBuffer.tokenizedLines[3].tokens[0]).toEqual({value: 'baz', scopes: ['source.js', 'meta.function-call.js', 'entity.name.function.js']})

              // previous line 2 is joined with quux() on line 4
              expect(tokenizedBuffer.tokenizedLines[4].tokens[0]).toEqual({value: 'quux', scopes: ['source.js', 'meta.function-call.js', 'entity.name.function.js']})
              expect(tokenizedBuffer.tokenizedLines[4].tokens[4]).toEqual({value: 'if', scopes: ['source.js', 'keyword.control.js']})

              // previous line 3 is pushed down to become line 5
              expect(tokenizedBuffer.tokenizedLines[5].tokens[3]).toEqual({value: '=', scopes: ['source.js', 'keyword.operator.assignment.js']})
            })
          })

          describe('when the change invalidates the tokenization of subsequent lines', () => {
            it('schedules the invalidated lines to be tokenized in the background', () => {
              buffer.insert([5, 30], '/* */')
              buffer.insert([2, 0], '/*\nabcde\nabcder')
              expect(tokenizedBuffer.tokenizedLines[2].tokens[0].scopes).toEqual(['source.js', 'comment.block.js', 'punctuation.definition.comment.begin.js'])
              expect(tokenizedBuffer.tokenizedLines[3].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[4].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[5].tokens[0].scopes).toEqual(['source.js'])

              advanceClock() // tokenize invalidated lines in background
              expect(tokenizedBuffer.tokenizedLines[5].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[6].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[7].tokens[0].scopes).toEqual(['source.js', 'comment.block.js'])
              expect(tokenizedBuffer.tokenizedLines[8].tokens[0].scopes).not.toBe(['source.js', 'comment.block.js'])
            })
          })
        })

        describe('when there is an insertion that is larger than the chunk size', () =>
          it('tokenizes the initial chunk synchronously, then tokenizes the remaining lines in the background', () => {
            const commentBlock = _.multiplyString('// a comment\n', tokenizedBuffer.chunkSize + 2)
            buffer.insert([0, 0], commentBlock)
            expect(tokenizedBuffer.tokenizedLines[0].ruleStack != null).toBeTruthy()
            expect(tokenizedBuffer.tokenizedLines[4].ruleStack != null).toBeTruthy()
            expect(tokenizedBuffer.tokenizedLines[5]).toBeUndefined()

            advanceClock()
            expect(tokenizedBuffer.tokenizedLines[5].ruleStack != null).toBeTruthy()
            expect(tokenizedBuffer.tokenizedLines[6].ruleStack != null).toBeTruthy()
          })
        )

        it('does not break out soft tabs across a scope boundary', async () => {
          await atom.packages.activatePackage('language-gfm')

          tokenizedBuffer.setTabLength(4)
          tokenizedBuffer.setGrammar(atom.grammars.selectGrammar('.md'))
          buffer.setText('    <![]()\n    ')
          fullyTokenize(tokenizedBuffer)

          let length = 0
          for (let tag of tokenizedBuffer.tokenizedLines[1].tags) {
            if (tag > 0) length += tag
          }

          expect(length).toBe(4)
        })
      })
    })

    describe('when the buffer contains hard-tabs', () => {
      beforeEach(async () => {
        atom.packages.activatePackage('language-coffee-script')

        buffer = atom.project.bufferForPathSync('sample-with-tabs.coffee')
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.coffee'), tabLength: 2})
        startTokenizing(tokenizedBuffer)
      })

      afterEach(() => {
        tokenizedBuffer.destroy()
        buffer.release()
      })

      describe('when the buffer is fully tokenized', () => {
        beforeEach(() => fullyTokenize(tokenizedBuffer))
      })
    })

    describe('when tokenization completes', () => {
      it('emits the `tokenized` event', async () => {
        const editor = await atom.workspace.open('sample.js')

        const tokenizedHandler = jasmine.createSpy('tokenized handler')
        editor.tokenizedBuffer.onDidTokenize(tokenizedHandler)
        fullyTokenize(editor.tokenizedBuffer)
        expect(tokenizedHandler.callCount).toBe(1)
      })

      it("doesn't re-emit the `tokenized` event when it is re-tokenized", async () => {
        const editor = await atom.workspace.open('sample.js')
        fullyTokenize(editor.tokenizedBuffer)

        const tokenizedHandler = jasmine.createSpy('tokenized handler')
        editor.tokenizedBuffer.onDidTokenize(tokenizedHandler)
        editor.getBuffer().insert([0, 0], "'")
        fullyTokenize(editor.tokenizedBuffer)
        expect(tokenizedHandler).not.toHaveBeenCalled()
      })
    })

    describe('when the grammar is updated because a grammar it includes is activated', async () => {
      it('re-emits the `tokenized` event', async () => {
        const editor = await atom.workspace.open('coffee.coffee')

        const tokenizedHandler = jasmine.createSpy('tokenized handler')
        editor.tokenizedBuffer.onDidTokenize(tokenizedHandler)
        fullyTokenize(editor.tokenizedBuffer)
        tokenizedHandler.reset()

        await atom.packages.activatePackage('language-coffee-script')
        fullyTokenize(editor.tokenizedBuffer)
        expect(tokenizedHandler.callCount).toBe(1)
      })

      it('retokenizes the buffer', async () => {
        await atom.packages.activatePackage('language-ruby-on-rails')
        await atom.packages.activatePackage('language-ruby')

        buffer = atom.project.bufferForPathSync()
        buffer.setText("<div class='name'><%= User.find(2).full_name %></div>")

        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.selectGrammar('test.erb'), tabLength: 2})
        fullyTokenize(tokenizedBuffer)
        expect(tokenizedBuffer.tokenizedLines[0].tokens[0]).toEqual({
          value: "<div class='name'>",
          scopes: ['text.html.ruby']
        })

        await atom.packages.activatePackage('language-html')
        fullyTokenize(tokenizedBuffer)
        expect(tokenizedBuffer.tokenizedLines[0].tokens[0]).toEqual({
          value: '<',
          scopes: ['text.html.ruby', 'meta.tag.block.div.html', 'punctuation.definition.tag.begin.html']
        })
      })
    })

    describe('when the buffer is configured with the null grammar', () => {
      it('does not actually tokenize using the grammar', () => {
        spyOn(NullGrammar, 'tokenizeLine').andCallThrough()
        buffer = atom.project.bufferForPathSync('sample.will-use-the-null-grammar')
        buffer.setText('a\nb\nc')
        tokenizedBuffer = new TokenizedBuffer({buffer, tabLength: 2})
        const tokenizeCallback = jasmine.createSpy('onDidTokenize')
        tokenizedBuffer.onDidTokenize(tokenizeCallback)

        expect(tokenizedBuffer.tokenizedLines[0]).toBeUndefined()
        expect(tokenizedBuffer.tokenizedLines[1]).toBeUndefined()
        expect(tokenizedBuffer.tokenizedLines[2]).toBeUndefined()
        expect(tokenizeCallback.callCount).toBe(0)
        expect(NullGrammar.tokenizeLine).not.toHaveBeenCalled()

        fullyTokenize(tokenizedBuffer)
        expect(tokenizedBuffer.tokenizedLines[0]).toBeUndefined()
        expect(tokenizedBuffer.tokenizedLines[1]).toBeUndefined()
        expect(tokenizedBuffer.tokenizedLines[2]).toBeUndefined()
        expect(tokenizeCallback.callCount).toBe(0)
        expect(NullGrammar.tokenizeLine).not.toHaveBeenCalled()
      })
    })
  })

  describe('.tokenForPosition(position)', () => {
    afterEach(() => {
      tokenizedBuffer.destroy()
      buffer.release()
    })

    it('returns the correct token (regression)', () => {
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
      fullyTokenize(tokenizedBuffer)
      expect(tokenizedBuffer.tokenForPosition([1, 0]).scopes).toEqual(['source.js'])
      expect(tokenizedBuffer.tokenForPosition([1, 1]).scopes).toEqual(['source.js'])
      expect(tokenizedBuffer.tokenForPosition([1, 2]).scopes).toEqual(['source.js', 'storage.type.var.js'])
    })
  })

  describe('.bufferRangeForScopeAtPosition(selector, position)', () => {
    beforeEach(() => {
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
      fullyTokenize(tokenizedBuffer)
    })

    describe('when the selector does not match the token at the position', () =>
      it('returns a falsy value', () => expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.bogus', [0, 1])).toBeUndefined())
    )

    describe('when the selector matches a single token at the position', () => {
      it('returns the range covered by the token', () => {
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.storage.type.var.js', [0, 1])).toEqual([[0, 0], [0, 3]])
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.storage.type.var.js', [0, 3])).toEqual([[0, 0], [0, 3]])
      })
    })

    describe('when the selector matches a run of multiple tokens at the position', () => {
      it('returns the range covered by all contiguous tokens (within a single line)', () => {
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.function', [1, 18])).toEqual([[1, 6], [1, 28]])
      })
    })
  })

  describe('.tokenizedLineForRow(row)', () => {
    it("returns the tokenized line for a row, or a placeholder line if it hasn't been tokenized yet", () => {
      buffer = atom.project.bufferForPathSync('sample.js')
      const grammar = atom.grammars.grammarForScopeName('source.js')
      tokenizedBuffer = new TokenizedBuffer({buffer, grammar, tabLength: 2})
      const line0 = buffer.lineForRow(0)

      const jsScopeStartId = grammar.startIdForScope(grammar.scopeName)
      const jsScopeEndId = grammar.endIdForScope(grammar.scopeName)
      startTokenizing(tokenizedBuffer)
      expect(tokenizedBuffer.tokenizedLines[0]).toBeUndefined()
      expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe(line0)
      expect(tokenizedBuffer.tokenizedLineForRow(0).tags).toEqual([jsScopeStartId, line0.length, jsScopeEndId])
      advanceClock(1)
      expect(tokenizedBuffer.tokenizedLines[0]).not.toBeUndefined()
      expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe(line0)
      expect(tokenizedBuffer.tokenizedLineForRow(0).tags).not.toEqual([jsScopeStartId, line0.length, jsScopeEndId])

      const nullScopeStartId = NullGrammar.startIdForScope(NullGrammar.scopeName)
      const nullScopeEndId = NullGrammar.endIdForScope(NullGrammar.scopeName)
      tokenizedBuffer.setGrammar(NullGrammar)
      startTokenizing(tokenizedBuffer)
      expect(tokenizedBuffer.tokenizedLines[0]).toBeUndefined()
      expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe(line0)
      expect(tokenizedBuffer.tokenizedLineForRow(0).tags).toEqual([nullScopeStartId, line0.length, nullScopeEndId])
      advanceClock(1)
      expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe(line0)
      expect(tokenizedBuffer.tokenizedLineForRow(0).tags).toEqual([nullScopeStartId, line0.length, nullScopeEndId])
    })

    it('returns undefined if the requested row is outside the buffer range', () => {
      buffer = atom.project.bufferForPathSync('sample.js')
      const grammar = atom.grammars.grammarForScopeName('source.js')
      tokenizedBuffer = new TokenizedBuffer({buffer, grammar, tabLength: 2})
      fullyTokenize(tokenizedBuffer)
      expect(tokenizedBuffer.tokenizedLineForRow(999)).toBeUndefined()
    })
  })

  describe('text decoration layer API', () => {
    describe('iterator', () => {
      it('iterates over the syntactic scope boundaries', () => {
        buffer = new TextBuffer({text: 'var foo = 1 /*\nhello*/var bar = 2\n'})
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
        fullyTokenize(tokenizedBuffer)

        const iterator = tokenizedBuffer.buildIterator()
        iterator.seek(Point(0, 0))

        const expectedBoundaries = [
          {position: Point(0, 0), closeTags: [], openTags: ['syntax--source syntax--js', 'syntax--storage syntax--type syntax--var syntax--js']},
          {position: Point(0, 3), closeTags: ['syntax--storage syntax--type syntax--var syntax--js'], openTags: []},
          {position: Point(0, 8), closeTags: [], openTags: ['syntax--keyword syntax--operator syntax--assignment syntax--js']},
          {position: Point(0, 9), closeTags: ['syntax--keyword syntax--operator syntax--assignment syntax--js'], openTags: []},
          {position: Point(0, 10), closeTags: [], openTags: ['syntax--constant syntax--numeric syntax--decimal syntax--js']},
          {position: Point(0, 11), closeTags: ['syntax--constant syntax--numeric syntax--decimal syntax--js'], openTags: []},
          {position: Point(0, 12), closeTags: [], openTags: ['syntax--comment syntax--block syntax--js', 'syntax--punctuation syntax--definition syntax--comment syntax--begin syntax--js']},
          {position: Point(0, 14), closeTags: ['syntax--punctuation syntax--definition syntax--comment syntax--begin syntax--js'], openTags: []},
          {position: Point(1, 5), closeTags: [], openTags: ['syntax--punctuation syntax--definition syntax--comment syntax--end syntax--js']},
          {position: Point(1, 7), closeTags: ['syntax--punctuation syntax--definition syntax--comment syntax--end syntax--js', 'syntax--comment syntax--block syntax--js'], openTags: ['syntax--storage syntax--type syntax--var syntax--js']},
          {position: Point(1, 10), closeTags: ['syntax--storage syntax--type syntax--var syntax--js'], openTags: []},
          {position: Point(1, 15), closeTags: [], openTags: ['syntax--keyword syntax--operator syntax--assignment syntax--js']},
          {position: Point(1, 16), closeTags: ['syntax--keyword syntax--operator syntax--assignment syntax--js'], openTags: []},
          {position: Point(1, 17), closeTags: [], openTags: ['syntax--constant syntax--numeric syntax--decimal syntax--js']},
          {position: Point(1, 18), closeTags: ['syntax--constant syntax--numeric syntax--decimal syntax--js'], openTags: []}
        ]

        while (true) {
          const boundary = {
            position: iterator.getPosition(),
            closeTags: iterator.getCloseScopeIds().map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId)),
            openTags: iterator.getOpenScopeIds().map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))
          }

          expect(boundary).toEqual(expectedBoundaries.shift())
          if (!iterator.moveToSuccessor()) { break }
        }

        expect(iterator.seek(Point(0, 1)).map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual([
          'syntax--source syntax--js',
          'syntax--storage syntax--type syntax--var syntax--js'
        ])
        expect(iterator.getPosition()).toEqual(Point(0, 3))
        expect(iterator.seek(Point(0, 8)).map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual([
          'syntax--source syntax--js'
        ])
        expect(iterator.getPosition()).toEqual(Point(0, 8))
        expect(iterator.seek(Point(1, 0)).map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual([
          'syntax--source syntax--js',
          'syntax--comment syntax--block syntax--js'
        ])
        expect(iterator.getPosition()).toEqual(Point(1, 0))
        expect(iterator.seek(Point(1, 18)).map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual([
          'syntax--source syntax--js',
          'syntax--constant syntax--numeric syntax--decimal syntax--js'
        ])
        expect(iterator.getPosition()).toEqual(Point(1, 18))

        expect(iterator.seek(Point(2, 0)).map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual([
          'syntax--source syntax--js'
        ])
        iterator.moveToSuccessor()
      }) // ensure we don't infinitely loop (regression test)

      it('does not report columns beyond the length of the line', async () => {
        await atom.packages.activatePackage('language-coffee-script')

        buffer = new TextBuffer({text: '# hello\n# world'})
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.coffee'), tabLength: 2})
        fullyTokenize(tokenizedBuffer)

        const iterator = tokenizedBuffer.buildIterator()
        iterator.seek(Point(0, 0))
        iterator.moveToSuccessor()
        iterator.moveToSuccessor()
        expect(iterator.getPosition().column).toBe(7)

        iterator.moveToSuccessor()
        expect(iterator.getPosition().column).toBe(0)

        iterator.seek(Point(0, 7))
        expect(iterator.getPosition().column).toBe(7)

        iterator.seek(Point(0, 8))
        expect(iterator.getPosition().column).toBe(7)
      })

      it('correctly terminates scopes at the beginning of the line (regression)', () => {
        const grammar = atom.grammars.createGrammar('test', {
          'scopeName': 'text.broken',
          'name': 'Broken grammar',
          'patterns': [
            {'begin': 'start', 'end': '(?=end)', 'name': 'blue.broken'},
            {'match': '.', 'name': 'yellow.broken'}
          ]
        })

        buffer = new TextBuffer({text: 'start x\nend x\nx'})
        tokenizedBuffer = new TokenizedBuffer({buffer, grammar, tabLength: 2})
        fullyTokenize(tokenizedBuffer)

        const iterator = tokenizedBuffer.buildIterator()
        iterator.seek(Point(1, 0))

        expect(iterator.getPosition()).toEqual([1, 0])
        expect(iterator.getCloseScopeIds().map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual(['syntax--blue syntax--broken'])
        expect(iterator.getOpenScopeIds().map(scopeId => tokenizedBuffer.classNameForScopeId(scopeId))).toEqual(['syntax--yellow syntax--broken'])
      })
    })
  })

  describe('.suggestedIndentForBufferRow', () => {
    let editor

    describe('javascript', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('sample.js', {autoIndent: false})
        await atom.packages.activatePackage('language-javascript')
      })

      it('bases indentation off of the previous non-blank line', () => {
        expect(editor.suggestedIndentForBufferRow(0)).toBe(0)
        expect(editor.suggestedIndentForBufferRow(1)).toBe(1)
        expect(editor.suggestedIndentForBufferRow(2)).toBe(2)
        expect(editor.suggestedIndentForBufferRow(5)).toBe(3)
        expect(editor.suggestedIndentForBufferRow(7)).toBe(2)
        expect(editor.suggestedIndentForBufferRow(9)).toBe(1)
        expect(editor.suggestedIndentForBufferRow(11)).toBe(1)
      })

      it('does not take invisibles into account', () => {
        editor.update({showInvisibles: true})
        expect(editor.suggestedIndentForBufferRow(0)).toBe(0)
        expect(editor.suggestedIndentForBufferRow(1)).toBe(1)
        expect(editor.suggestedIndentForBufferRow(2)).toBe(2)
        expect(editor.suggestedIndentForBufferRow(5)).toBe(3)
        expect(editor.suggestedIndentForBufferRow(7)).toBe(2)
        expect(editor.suggestedIndentForBufferRow(9)).toBe(1)
        expect(editor.suggestedIndentForBufferRow(11)).toBe(1)
      })
    })

    describe('css', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('css.css', {autoIndent: true})
        await atom.packages.activatePackage('language-source')
        await atom.packages.activatePackage('language-css')
      })

      it('does not return negative values (regression)', () => {
        editor.setText('.test {\npadding: 0;\n}')
        expect(editor.suggestedIndentForBufferRow(2)).toBe(0)
      })
    })
  })

  describe('.toggleLineCommentsForBufferRows', () => {
    describe('xml', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-xml')
        buffer = new TextBuffer('<!-- test -->')
        tokenizedBuffer = new TokenizedBuffer({
          buffer,
          grammar: atom.grammars.grammarForScopeName('text.xml'),
          scopedSettingsDelegate: new ScopedSettingsDelegate(atom.config)
        })
      })

      it('removes the leading whitespace from the comment end pattern match when uncommenting lines', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe('test')
      })
    })

    describe('less', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-less')
        await atom.packages.activatePackage('language-css')
        buffer = await TextBuffer.load(require.resolve('./fixtures/sample.less'))
        tokenizedBuffer = new TokenizedBuffer({
          buffer,
          grammar: atom.grammars.grammarForScopeName('source.css.less'),
          scopedSettingsDelegate: new ScopedSettingsDelegate(atom.config)
        })
      })

      it('only uses the `commentEnd` pattern if it comes from the same grammar as the `commentStart` when commenting lines', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe('// @color: #4D926F;')
      })
    })

    describe('css', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-css')
        buffer = await TextBuffer.load(require.resolve('./fixtures/css.css'))
        tokenizedBuffer = new TokenizedBuffer({
          buffer,
          grammar: atom.grammars.grammarForScopeName('source.css'),
          scopedSettingsDelegate: new ScopedSettingsDelegate(atom.config)
        })
      })

      it('comments/uncomments lines in the given range', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe('/*body {')
        expect(buffer.lineForRow(1)).toBe('  font-size: 1234px;*/')
        expect(buffer.lineForRow(2)).toBe('  width: 110%;')
        expect(buffer.lineForRow(3)).toBe('  font-weight: bold !important;')

        tokenizedBuffer.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(0)).toBe('/*body {')
        expect(buffer.lineForRow(1)).toBe('  font-size: 1234px;*/')
        expect(buffer.lineForRow(2)).toBe('  /*width: 110%;*/')
        expect(buffer.lineForRow(3)).toBe('  font-weight: bold !important;')

        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe('body {')
        expect(buffer.lineForRow(1)).toBe('  font-size: 1234px;')
        expect(buffer.lineForRow(2)).toBe('  /*width: 110%;*/')
        expect(buffer.lineForRow(3)).toBe('  font-weight: bold !important;')
      })

      it('uncomments lines with leading whitespace', () => {
        buffer.setTextInRange([[2, 0], [2, Infinity]], '  /*width: 110%;*/')
        tokenizedBuffer.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe('  width: 110%;')
      })

      it('uncomments lines with trailing whitespace', () => {
        buffer.setTextInRange([[2, 0], [2, Infinity]], '/*width: 110%;*/  ')
        tokenizedBuffer.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe('width: 110%;  ')
      })

      it('uncomments lines with leading and trailing whitespace', () => {
        buffer.setTextInRange([[2, 0], [2, Infinity]], '   /*width: 110%;*/ ')
        tokenizedBuffer.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe('   width: 110%; ')
      })
    })

    describe('coffeescript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-coffee-script')
        buffer = await TextBuffer.load(require.resolve('./fixtures/coffee.coffee'))
        tokenizedBuffer = new TokenizedBuffer({
          buffer,
          tabLength: 2,
          grammar: atom.grammars.grammarForScopeName('source.coffee'),
          scopedSettingsDelegate: new ScopedSettingsDelegate(atom.config)
        })
      })

      it('comments/uncomments lines in the given range', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 6)
        expect(buffer.lineForRow(4)).toBe('    # pivot = items.shift()')
        expect(buffer.lineForRow(5)).toBe('    # left = []')
        expect(buffer.lineForRow(6)).toBe('    # right = []')

        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe('    pivot = items.shift()')
        expect(buffer.lineForRow(5)).toBe('    left = []')
        expect(buffer.lineForRow(6)).toBe('    # right = []')
      })

      it('comments/uncomments empty lines', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe('    # pivot = items.shift()')
        expect(buffer.lineForRow(5)).toBe('    # left = []')
        expect(buffer.lineForRow(6)).toBe('    # right = []')
        expect(buffer.lineForRow(7)).toBe('    # ')

        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe('    pivot = items.shift()')
        expect(buffer.lineForRow(5)).toBe('    left = []')
        expect(buffer.lineForRow(6)).toBe('    # right = []')
        expect(buffer.lineForRow(7)).toBe('    # ')
      })
    })

    describe('javascript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-javascript')
        buffer = await TextBuffer.load(require.resolve('./fixtures/sample.js'))
        tokenizedBuffer = new TokenizedBuffer({
          buffer,
          tabLength: 2,
          grammar: atom.grammars.grammarForScopeName('source.js'),
          scopedSettingsDelegate: new ScopedSettingsDelegate(atom.config)
        })
      })

      it('comments/uncomments lines in the given range', () => {
        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe('    // while(items.length > 0) {')
        expect(buffer.lineForRow(5)).toBe('    //   current = items.shift();')
        expect(buffer.lineForRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
        expect(buffer.lineForRow(7)).toBe('    // }')

        tokenizedBuffer.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe('    while(items.length > 0) {')
        expect(buffer.lineForRow(5)).toBe('      current = items.shift();')
        expect(buffer.lineForRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
        expect(buffer.lineForRow(7)).toBe('    // }')

        buffer.setText('\tvar i;')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe('\t// var i;')

        buffer.setText('var i;')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe('// var i;')

        buffer.setText(' var i;')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe(' // var i;')

        buffer.setText('  ')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe('  // ')

        buffer.setText('    a\n  \n    b')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 2)
        expect(buffer.lineForRow(0)).toBe('    // a')
        expect(buffer.lineForRow(1)).toBe('    // ')
        expect(buffer.lineForRow(2)).toBe('    // b')

        buffer.setText('    \n    // var i;')
        tokenizedBuffer.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe('    ')
        expect(buffer.lineForRow(1)).toBe('    var i;')
      })
    })
  })

  describe('.isFoldableAtRow(row)', () => {
    beforeEach(() => {
      buffer = atom.project.bufferForPathSync('sample.js')
      buffer.insert([10, 0], '  // multi-line\n  // comment\n  // block\n')
      buffer.insert([0, 0], '// multi-line\n// comment\n// block\n')
      tokenizedBuffer = new TokenizedBuffer({buffer, grammar: atom.grammars.grammarForScopeName('source.js'), tabLength: 2})
      fullyTokenize(tokenizedBuffer)
    })

    it('includes the first line of multi-line comments', () => {
      expect(tokenizedBuffer.isFoldableAtRow(0)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(1)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(2)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(3)).toBe(true) // because of indent
      expect(tokenizedBuffer.isFoldableAtRow(13)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(14)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(15)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(16)).toBe(false)

      buffer.insert([0, Infinity], '\n')

      expect(tokenizedBuffer.isFoldableAtRow(0)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(1)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(2)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(3)).toBe(false)

      buffer.undo()

      expect(tokenizedBuffer.isFoldableAtRow(0)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(1)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(2)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(3)).toBe(true)
    }) // because of indent

    it('includes non-comment lines that precede an increase in indentation', () => {
      buffer.insert([2, 0], '  ') // commented lines preceding an indent aren't foldable

      expect(tokenizedBuffer.isFoldableAtRow(1)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(2)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(3)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(4)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(5)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(6)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(7)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(8)).toBe(false)

      buffer.insert([7, 0], '  ')

      expect(tokenizedBuffer.isFoldableAtRow(6)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(7)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(8)).toBe(false)

      buffer.undo()

      expect(tokenizedBuffer.isFoldableAtRow(6)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(7)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(8)).toBe(false)

      buffer.insert([7, 0], '    \n      x\n')

      expect(tokenizedBuffer.isFoldableAtRow(6)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(7)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(8)).toBe(false)

      buffer.insert([9, 0], '  ')

      expect(tokenizedBuffer.isFoldableAtRow(6)).toBe(true)
      expect(tokenizedBuffer.isFoldableAtRow(7)).toBe(false)
      expect(tokenizedBuffer.isFoldableAtRow(8)).toBe(false)
    })
  })

  describe('.getFoldableRangesAtIndentLevel', () => {
    it('returns the ranges that can be folded at the given indent level', () => {
      buffer = new TextBuffer(dedent `
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
      `)

      tokenizedBuffer = new TokenizedBuffer({buffer})

      expect(simulateFold(tokenizedBuffer.getFoldableRangesAtIndentLevel(0, 2))).toBe(dedent `
        if (a) {⋯
        }
        i()
        if (j) {⋯
        }
      `)

      expect(simulateFold(tokenizedBuffer.getFoldableRangesAtIndentLevel(1, 2))).toBe(dedent `
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
      `)

      expect(simulateFold(tokenizedBuffer.getFoldableRangesAtIndentLevel(2, 2))).toBe(dedent `
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
      `)
    })
  })

  describe('.getFoldableRanges', () => {
    it('returns the ranges that can be folded', () => {
      buffer = new TextBuffer(dedent `
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
      `)

      tokenizedBuffer = new TokenizedBuffer({buffer})

      expect(tokenizedBuffer.getFoldableRanges(2).map(r => r.toString())).toEqual([
        ...tokenizedBuffer.getFoldableRangesAtIndentLevel(0, 2),
        ...tokenizedBuffer.getFoldableRangesAtIndentLevel(1, 2),
        ...tokenizedBuffer.getFoldableRangesAtIndentLevel(2, 2),
      ].sort((a, b) => (a.start.row - b.start.row) || (a.end.row - b.end.row)).map(r => r.toString()))
    })
  })

  describe('.getFoldableRangeContainingPoint', () => {
    it('returns the range for the smallest fold that contains the given range', () => {
      buffer = new TextBuffer(dedent `
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
      `)

      tokenizedBuffer = new TokenizedBuffer({buffer})

      expect(tokenizedBuffer.getFoldableRangeContainingPoint(Point(0, 5), 2)).toBeNull()

      let range = tokenizedBuffer.getFoldableRangeContainingPoint(Point(0, 10), 2)
      expect(simulateFold([range])).toBe(dedent `
        if (a) {⋯
        }
        i()
        if (j) {
          k()
        }
      `)

      range = tokenizedBuffer.getFoldableRangeContainingPoint(Point(1, Infinity), 2)
      expect(simulateFold([range])).toBe(dedent `
        if (a) {⋯
        }
        i()
        if (j) {
          k()
        }
      `)

      range = tokenizedBuffer.getFoldableRangeContainingPoint(Point(2, 20), 2)
      expect(simulateFold([range])).toBe(dedent `
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
      `)
    })

    it('works for coffee-script', async () => {
      const editor = await atom.workspace.open('coffee.coffee')
      await atom.packages.activatePackage('language-coffee-script')
      buffer = editor.buffer
      tokenizedBuffer = editor.tokenizedBuffer

      expect(tokenizedBuffer.getFoldableRangeContainingPoint(Point(0, Infinity))).toEqual([[0, Infinity], [20, Infinity]])
      expect(tokenizedBuffer.getFoldableRangeContainingPoint(Point(1, Infinity))).toEqual([[1, Infinity], [17, Infinity]])
      expect(tokenizedBuffer.getFoldableRangeContainingPoint(Point(2, Infinity))).toEqual([[1, Infinity], [17, Infinity]])
      expect(tokenizedBuffer.getFoldableRangeContainingPoint(Point(19, Infinity))).toEqual([[19, Infinity], [20, Infinity]])
    })

    it('works for javascript', async () => {
      const editor = await atom.workspace.open('sample.js')
      await atom.packages.activatePackage('language-javascript')
      buffer = editor.buffer
      tokenizedBuffer = editor.tokenizedBuffer

      expect(editor.tokenizedBuffer.getFoldableRangeContainingPoint(Point(0, Infinity))).toEqual([[0, Infinity], [12, Infinity]])
      expect(editor.tokenizedBuffer.getFoldableRangeContainingPoint(Point(1, Infinity))).toEqual([[1, Infinity], [9, Infinity]])
      expect(editor.tokenizedBuffer.getFoldableRangeContainingPoint(Point(2, Infinity))).toEqual([[1, Infinity], [9, Infinity]])
      expect(editor.tokenizedBuffer.getFoldableRangeContainingPoint(Point(4, Infinity))).toEqual([[4, Infinity], [7, Infinity]])
    })
  })

  function simulateFold (ranges) {
    buffer.transact(() => {
      for (const range of ranges.reverse()) {
        buffer.setTextInRange(range, '⋯')
      }
    })
    let text = buffer.getText()
    buffer.undo()
    return text
  }
})
