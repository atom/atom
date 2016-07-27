_ = require 'underscore-plus'
randomWords = require 'random-words'
TextBuffer = require 'text-buffer'
{Point, Range} = TextBuffer
TextEditor = require '../src/text-editor'
TextEditorPresenter = require '../src/text-editor-presenter'
FakeLinesYardstick = require './fake-lines-yardstick'
LineTopIndex = require 'line-top-index'

describe "TextEditorPresenter", ->
  # These `describe` and `it` blocks mirror the structure of the ::state object.
  # Please maintain this structure when adding specs for new state fields.
  describe "::get(Pre|Post)MeasurementState()", ->
    [buffer, editor] = []

    beforeEach ->
      # These *should* be mocked in the spec helper, but changing that now would break packages :-(
      spyOn(window, "setInterval").andCallFake window.fakeSetInterval
      spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

      buffer = new TextBuffer(filePath: require.resolve('./fixtures/sample.js'))
      editor = atom.workspace.buildTextEditor({buffer})
      waitsForPromise -> buffer.load()

    afterEach ->
      editor.destroy()
      buffer.destroy()

    getState = (presenter) ->
      presenter.getPreMeasurementState()
      presenter.getPostMeasurementState()

    addBlockDecorationBeforeScreenRow = (screenRow, item) ->
      editor.decorateMarker(
        editor.markScreenPosition([screenRow, 0], invalidate: "never"),
        type: "block", item: item, position: "before"
      )

    addBlockDecorationAfterScreenRow = (screenRow, item) ->
      editor.decorateMarker(
        editor.markScreenPosition([screenRow, 0], invalidate: "never"),
        type: "block", item: item, position: "after"
      )

    buildPresenterWithoutMeasurements = (params={}) ->
      lineTopIndex = new LineTopIndex({
        defaultLineHeight: editor.getLineHeightInPixels()
      })
      _.defaults params,
        model: editor
        config: atom.config
        contentFrameWidth: 500
        lineTopIndex: lineTopIndex
      presenter = new TextEditorPresenter(params)
      presenter.setLinesYardstick(new FakeLinesYardstick(editor, lineTopIndex))
      presenter

    buildPresenter = (params={}) ->
      presenter = buildPresenterWithoutMeasurements(params)
      presenter.setScrollTop(params.scrollTop) if params.scrollTop?
      presenter.setScrollLeft(params.scrollLeft) if params.scrollLeft?
      presenter.setExplicitHeight(params.explicitHeight ? 130)
      presenter.setWindowSize(params.windowWidth ? 500, params.windowHeight ? 130)
      presenter.setBoundingClientRect(params.boundingClientRect ? {
        left: 0
        top: 0
        width: 500
        height: 130
      })
      presenter.setGutterWidth(params.gutterWidth ? 0)
      presenter.setLineHeight(params.lineHeight ? 10)
      presenter.setBaseCharacterWidth(params.baseCharacterWidth ? 10)
      presenter.setHorizontalScrollbarHeight(params.horizontalScrollbarHeight ? 10)
      presenter.setVerticalScrollbarWidth(params.verticalScrollbarWidth ? 10)
      presenter

    expectValues = (actual, expected) ->
      for key, value of expected
        expect(actual[key]).toEqual value

    expectStateUpdatedToBe = (value, presenter, fn) ->
      updatedState = false
      disposable = presenter.onDidUpdateState ->
        updatedState = true
        disposable.dispose()
      fn()
      expect(updatedState).toBe(value)

    expectStateUpdate = (presenter, fn) -> expectStateUpdatedToBe(true, presenter, fn)

    expectNoStateUpdate = (presenter, fn) -> expectStateUpdatedToBe(false, presenter, fn)

    waitsForStateToUpdate = (presenter, fn) ->
      line = new Error().stack.split('\n')[2].split(':')[1]

      waitsFor "presenter state to update at line #{line}", 1000, (done) ->
        disposable = presenter.onDidUpdateState ->
          disposable.dispose()
          process.nextTick(done)
        fn?()

    tiledContentContract = (stateFn) ->
      it "contains states for tiles that are visible on screen", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)

        expectValues stateFn(presenter).tiles[0], {
          top: 0
        }
        expectValues stateFn(presenter).tiles[2], {
          top: 2
        }
        expectValues stateFn(presenter).tiles[4], {
          top: 4
        }
        expectValues stateFn(presenter).tiles[6], {
          top: 6
        }

        expect(stateFn(presenter).tiles[8]).toBeUndefined()

        expectStateUpdate presenter, -> presenter.setScrollTop(3)

        expect(stateFn(presenter).tiles[0]).toBeUndefined()

        expectValues stateFn(presenter).tiles[2], {
          top: -1
        }
        expectValues stateFn(presenter).tiles[4], {
          top: 1
        }
        expectValues stateFn(presenter).tiles[6], {
          top: 3
        }
        expectValues stateFn(presenter).tiles[8], {
          top: 5
        }
        expectValues stateFn(presenter).tiles[10], {
          top: 7
        }

        expect(stateFn(presenter).tiles[12]).toBeUndefined()

      it "includes state for tiles containing screen rows to measure", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)
        presenter.setScreenRowsToMeasure([10, 12])

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()
        expect(stateFn(presenter).tiles[10]).toBeDefined()
        expect(stateFn(presenter).tiles[12]).toBeDefined()

        # clearing additional rows won't trigger a state update
        expectNoStateUpdate presenter, -> presenter.clearScreenRowsToMeasure()

        # when another change triggers a state update we remove useless lines
        expectStateUpdate presenter, -> presenter.setScrollTop(1)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeDefined()
        expect(stateFn(presenter).tiles[10]).toBeUndefined()
        expect(stateFn(presenter).tiles[12]).toBeUndefined()

      it "excludes invalid tiles for screen rows to measure", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)
        presenter.setScreenRowsToMeasure([20, 30]) # unexisting rows

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()
        expect(stateFn(presenter).tiles[10]).toBeUndefined()
        expect(stateFn(presenter).tiles[12]).toBeUndefined()

        presenter.setScreenRowsToMeasure([12])
        buffer.deleteRows(12, 13)

        expect(stateFn(presenter).tiles[12]).toBeUndefined()

      describe "when there are block decorations", ->
        it "computes each tile's height and scrollTop based on block decorations' height", ->
          presenter = buildPresenter(explicitHeight: 120, scrollTop: 0, lineHeight: 10, tileSize: 2)

          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(5)
          blockDecoration4 = addBlockDecorationAfterScreenRow(5)
          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 1)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 30)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 40)
          presenter.setBlockDecorationDimensions(blockDecoration4, 0, 50)

          expect(stateFn(presenter).tiles[0].height).toBe(2 * 10 + 1)
          expect(stateFn(presenter).tiles[0].top).toBe(0 * 10)
          expect(stateFn(presenter).tiles[2].height).toBe(2 * 10 + 30)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 1)
          expect(stateFn(presenter).tiles[4].height).toBe(2 * 10 + 40 + 50)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 1 + 30)
          expect(stateFn(presenter).tiles[6].height).toBe(2 * 10)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 1 + 30 + 40 + 50)
          expect(stateFn(presenter).tiles[8]).toBeUndefined()

          presenter.setScrollTop(21)

          expect(stateFn(presenter).tiles[0]).toBeUndefined()
          expect(stateFn(presenter).tiles[2].height).toBe(2 * 10 + 30)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 1 - 21)
          expect(stateFn(presenter).tiles[4].height).toBe(2 * 10 + 40 + 50)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 1 + 30 - 21)
          expect(stateFn(presenter).tiles[6].height).toBe(2 * 10)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 1 + 30 + 40 + 50 - 21)
          expect(stateFn(presenter).tiles[8]).toBeUndefined()

          blockDecoration3.getMarker().setHeadScreenPosition([6, 0])

          expect(stateFn(presenter).tiles[0]).toBeUndefined()
          expect(stateFn(presenter).tiles[2].height).toBe(2 * 10 + 30)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 1 - 21)
          expect(stateFn(presenter).tiles[4].height).toBe(2 * 10 + 50)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 1 + 30 - 21)
          expect(stateFn(presenter).tiles[6].height).toBe(2 * 10 + 40)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 1 + 30 + 50 - 21)
          expect(stateFn(presenter).tiles[8]).toBeUndefined()

        it "works correctly when soft wrapping is enabled", ->
          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(4)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(8)

          presenter = buildPresenter(explicitHeight: 330, lineHeight: 10, tileSize: 2, baseCharacterWidth: 5)

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 10)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 20)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 30)

          expect(stateFn(presenter).tiles[0].top).toBe(0 * 10)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 10)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 10)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[8].top).toBe(8 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[10].top).toBe(10 * 10 + 10 + 20 + 30)
          expect(stateFn(presenter).tiles[12].top).toBe(12 * 10 + 10 + 20 + 30)

          editor.setSoftWrapped(true)
          presenter.setContentFrameWidth(5 * 25)

          expect(stateFn(presenter).tiles[0].top).toBe(0 * 10)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 10)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 10)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 10)
          expect(stateFn(presenter).tiles[8].top).toBe(8 * 10 + 10)
          expect(stateFn(presenter).tiles[10].top).toBe(10 * 10 + 10)
          expect(stateFn(presenter).tiles[12].top).toBe(12 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[14].top).toBe(14 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[16].top).toBe(16 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[18].top).toBe(18 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[20].top).toBe(20 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[22].top).toBe(22 * 10 + 10 + 20 + 30)
          expect(stateFn(presenter).tiles[24].top).toBe(24 * 10 + 10 + 20 + 30)
          expect(stateFn(presenter).tiles[26].top).toBe(26 * 10 + 10 + 20 + 30)
          expect(stateFn(presenter).tiles[28].top).toBe(28 * 10 + 10 + 20 + 30)

          editor.setSoftWrapped(false)

          expect(stateFn(presenter).tiles[0].top).toBe(0 * 10)
          expect(stateFn(presenter).tiles[2].top).toBe(2 * 10 + 10)
          expect(stateFn(presenter).tiles[4].top).toBe(4 * 10 + 10)
          expect(stateFn(presenter).tiles[6].top).toBe(6 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[8].top).toBe(8 * 10 + 10 + 20)
          expect(stateFn(presenter).tiles[10].top).toBe(10 * 10 + 10 + 20 + 30)
          expect(stateFn(presenter).tiles[12].top).toBe(12 * 10 + 10 + 20 + 30)

      it "includes state for all tiles if no external ::explicitHeight is assigned", ->
        presenter = buildPresenter(explicitHeight: null, tileSize: 2)
        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[12]).toBeDefined()

      it "is empty until all of the required measurements are assigned", ->
        presenter = buildPresenterWithoutMeasurements()
        expect(stateFn(presenter).tiles).toEqual({})

        presenter.setExplicitHeight(25)
        expect(stateFn(presenter).tiles).toEqual({})

        # Sets scroll row from model's logical position
        presenter.setLineHeight(10)
        expect(stateFn(presenter).tiles).not.toEqual({})

      it "updates when ::scrollTop changes", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()

        expectStateUpdate presenter, -> presenter.setScrollTop(2)

        expect(stateFn(presenter).tiles[0]).toBeUndefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeDefined()
        expect(stateFn(presenter).tiles[10]).toBeUndefined()

      it "updates when ::explicitHeight changes", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()

        expectStateUpdate presenter, -> presenter.setExplicitHeight(8)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeDefined()
        expect(stateFn(presenter).tiles[10]).toBeUndefined()

      it "updates when ::lineHeight changes", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()

        expectStateUpdate presenter, -> presenter.setLineHeight(4)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeDefined()
        expect(stateFn(presenter).tiles[4]).toBeUndefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()

      it "does not remove out-of-view tiles corresponding to ::mouseWheelScreenRow until ::stoppedScrollingDelay elapses", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2, stoppedScrollingDelay: 200)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[6]).toBeDefined()
        expect(stateFn(presenter).tiles[8]).toBeUndefined()

        presenter.setMouseWheelScreenRow(0)
        expectStateUpdate presenter, -> presenter.setScrollTop(4)

        expect(stateFn(presenter).tiles[0]).toBeDefined()
        expect(stateFn(presenter).tiles[2]).toBeUndefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[12]).toBeUndefined()

        expectStateUpdate presenter, -> advanceClock(200)

        expect(stateFn(presenter).tiles[0]).toBeUndefined()
        expect(stateFn(presenter).tiles[2]).toBeUndefined()
        expect(stateFn(presenter).tiles[4]).toBeDefined()
        expect(stateFn(presenter).tiles[12]).toBeUndefined()


        # should clear ::mouseWheelScreenRow after stoppedScrollingDelay elapses even if we don't scroll first
        presenter.setMouseWheelScreenRow(4)
        advanceClock(200)
        expectStateUpdate presenter, -> presenter.setScrollTop(6)
        expect(stateFn(presenter).tiles[4]).toBeUndefined()

      it "does not preserve deleted on-screen tiles even if they correspond to ::mouseWheelScreenRow", ->
        presenter = buildPresenter(explicitHeight: 6, scrollTop: 0, lineHeight: 1, tileSize: 2, stoppedScrollingDelay: 200)

        presenter.setMouseWheelScreenRow(2)

        expectStateUpdate presenter, -> editor.setText("")

        expect(stateFn(presenter).tiles[2]).toBeUndefined()
        expect(stateFn(presenter).tiles[0]).toBeDefined()

    describe "during state retrieval", ->
      it "does not trigger onDidUpdateState events", ->
        presenter = buildPresenter()
        expectNoStateUpdate presenter, -> getState(presenter)

    describe ".horizontalScrollbar", ->
      describe ".visible", ->
        it "is true if the scrollWidth exceeds the computed client width", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 + 1
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(getState(presenter).horizontalScrollbar.visible).toBe false

          # ::contentFrameWidth itself is smaller than scrollWidth
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(getState(presenter).horizontalScrollbar.visible).toBe true

          # restore...
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10 + 1)
          expect(getState(presenter).horizontalScrollbar.visible).toBe false

          # visible vertical scrollbar makes the clientWidth smaller than the scrollWidth
          presenter.setExplicitHeight((editor.getLineCount() * 10) - 1)
          expect(getState(presenter).horizontalScrollbar.visible).toBe true

        it "is false if the editor is mini", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 - 10
            baseCharacterWidth: 10

          expect(getState(presenter).horizontalScrollbar.visible).toBe true
          editor.setMini(true)
          expect(getState(presenter).horizontalScrollbar.visible).toBe false
          editor.setMini(false)
          expect(getState(presenter).horizontalScrollbar.visible).toBe true

      describe ".height", ->
        it "tracks the value of ::horizontalScrollbarHeight", ->
          presenter = buildPresenter(horizontalScrollbarHeight: 10)
          expect(getState(presenter).horizontalScrollbar.height).toBe 10
          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(20)
          expect(getState(presenter).horizontalScrollbar.height).toBe 20

      describe ".right", ->
        it "is ::verticalScrollbarWidth if the vertical scrollbar is visible and 0 otherwise", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10 + 50
            contentFrameWidth: editor.getMaxScreenLineLength() * 10
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(getState(presenter).horizontalScrollbar.right).toBe 0
          presenter.setExplicitHeight((editor.getLineCount() * 10) - 1)
          expect(getState(presenter).horizontalScrollbar.right).toBe 10

      describe ".scrollWidth", ->
        it "is initialized as the max of the ::contentFrameWidth and the width of the longest line", ->
          maxLineLength = editor.getMaxScreenLineLength()

          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1

          presenter = buildPresenter(contentFrameWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::contentFrameWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setContentFrameWidth(10 * maxLineLength + 20)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when character widths change", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            maxLineLength = editor.getMaxScreenLineLength()
            presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

            expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1
            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'meta.method-call.js', 'support.function.js'], 'p', 20)
              presenter.measurementsChanged()
            expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

        it "updates when ::softWrapped changes on the editor", ->
          presenter = buildPresenter(contentFrameWidth: 470, baseCharacterWidth: 10)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
          expectStateUpdate presenter, -> editor.setSoftWrapped(true)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe presenter.clientWidth
          expectStateUpdate presenter, -> editor.setSoftWrapped(false)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "updates when the longest line changes", ->
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([editor.getLongestScreenRow(), 0])
          expectStateUpdate presenter, -> editor.insertText('xyz')

          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

      describe ".scrollLeft", ->
        it "tracks the value of ::scrollLeft", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe 50

        it "never exceeds the computed scrollWidth minus the computed clientWidth", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, explicitHeight: 100, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(300)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setContentFrameWidth(600)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(5)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> editor.getBuffer().delete([[6, 0], [6, Infinity]])
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollLeftBefore = getState(presenter).horizontalScrollbar.scrollLeft
          expectStateUpdate presenter, -> editor.getBuffer().insert([6, 0], new Array(100).join('x'))
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe scrollLeftBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(-300)
          expect(getState(presenter).horizontalScrollbar.scrollLeft).toBe 0

        it "is always 0 when soft wrapping is enabled", ->
          presenter = buildPresenter(scrollLeft: 0, verticalScrollbarWidth: 0, contentFrameWidth: 85, baseCharacterWidth: 10)

          editor.setSoftWrapped(false)
          presenter.setScrollLeft(Infinity)
          expect(getState(presenter).content.scrollLeft).toBeGreaterThan 0

          editor.setSoftWrapped(true)
          expect(getState(presenter).content.scrollLeft).toBe 0
          presenter.setScrollLeft(10)
          expect(getState(presenter).content.scrollLeft).toBe 0

    describe ".verticalScrollbar", ->
      describe ".visible", ->
        it "is true if the scrollHeight exceeds the computed client height", ->
          presenter = buildPresenter
            model: editor
            explicitHeight: editor.getLineCount() * 10
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 + 1
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(getState(presenter).verticalScrollbar.visible).toBe false

          # ::explicitHeight itself is smaller than scrollWidth
          presenter.setExplicitHeight(editor.getLineCount() * 10 - 1)
          expect(getState(presenter).verticalScrollbar.visible).toBe true

          # restore...
          presenter.setExplicitHeight(editor.getLineCount() * 10)
          expect(getState(presenter).verticalScrollbar.visible).toBe false

          # visible horizontal scrollbar makes the clientHeight smaller than the scrollHeight
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(getState(presenter).verticalScrollbar.visible).toBe true

      describe ".width", ->
        it "is assigned based on ::verticalScrollbarWidth", ->
          presenter = buildPresenter(verticalScrollbarWidth: 10)
          expect(getState(presenter).verticalScrollbar.width).toBe 10
          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(20)
          expect(getState(presenter).verticalScrollbar.width).toBe 20

      describe ".bottom", ->
        it "is ::horizontalScrollbarHeight if the horizontal scrollbar is visible and 0 otherwise", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10 - 1
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 + 50
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(getState(presenter).verticalScrollbar.bottom).toBe 0
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(getState(presenter).verticalScrollbar.bottom).toBe 10

      describe ".scrollHeight", ->
        it "is initialized based on the lineHeight, the number of lines, and the height", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 500)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe 500

        it "updates when new block decorations are measured, changed or destroyed", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(7)

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 35.8)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 50.3)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 95.2)

          linesHeight = editor.getScreenLineCount() * 10
          blockDecorationsHeight = Math.round(35.8 + 50.3 + 95.2)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 100.3)

          blockDecorationsHeight = Math.round(35.8 + 100.3 + 95.2)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

          waitsForStateToUpdate presenter, -> blockDecoration3.destroy()
          runs ->
            blockDecorationsHeight = Math.round(35.8 + 100.3)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

        it "updates when the ::lineHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe 500

        describe "scrollPastEnd", ->
          it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
            expectStateUpdate presenter, -> presenter.setScrollTop(300)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight

          it "doesn't add the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true but the presenter is created with scrollPastEnd as false", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10, scrollPastEnd: false)
            expectStateUpdate presenter, -> presenter.setScrollTop(300)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe presenter.contentHeight

      describe ".scrollTop", ->
        it "tracks the value of ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 20, horizontalScrollbarHeight: 10)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe 50

        it "never exceeds the computed scrollHeight minus the computed clientHeight", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(100)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollTopBefore = getState(presenter).verticalScrollbar.scrollTop
          expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe scrollTopBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(-100)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe 0

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

          atom.config.set("editor.scrollPastEnd", true)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(getState(presenter).verticalScrollbar.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

    describe ".hiddenInput", ->
      describe ".top/.left", ->
        it "is positioned over the last cursor it is in view and the editor is focused", ->
          editor.setCursorBufferPosition([3, 6])
          presenter = buildPresenter(focused: false, explicitHeight: 50, contentFrameWidth: 300, horizontalScrollbarHeight: 0, verticalScrollbarWidth: 0)
          expectValues getState(presenter).hiddenInput, {top: 0, left: 0}

          expectStateUpdate presenter, -> presenter.setFocused(true)
          expectValues getState(presenter).hiddenInput, {top: 3 * 10, left: 6 * 10}

          expectStateUpdate presenter, -> presenter.setScrollTop(15)
          expectValues getState(presenter).hiddenInput, {top: (3 * 10) - 15, left: 6 * 10}

          expectStateUpdate presenter, -> presenter.setScrollLeft(35)
          expectValues getState(presenter).hiddenInput, {top: (3 * 10) - 15, left: (6 * 10) - 35}

          expectStateUpdate presenter, -> presenter.setScrollTop(40)
          expectValues getState(presenter).hiddenInput, {top: 0, left: (6 * 10) - 35}

          expectStateUpdate presenter, -> presenter.setScrollLeft(70)
          expectValues getState(presenter).hiddenInput, {top: 0, left: 0}

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([11, 43])
          expectValues getState(presenter).hiddenInput, {top: 11 * 10 - presenter.getScrollTop(), left: 43 * 10 - presenter.getScrollLeft()}

          newCursor = null
          expectStateUpdate presenter, -> newCursor = editor.addCursorAtBufferPosition([6, 10])
          expectValues getState(presenter).hiddenInput, {top: (6 * 10) - presenter.getScrollTop(), left: (10 * 10) - presenter.getScrollLeft()}

          expectStateUpdate presenter, -> newCursor.destroy()
          expectValues getState(presenter).hiddenInput, {top: 50 - 10, left: 300 - 10}

          expectStateUpdate presenter, -> presenter.setFocused(false)
          expectValues getState(presenter).hiddenInput, {top: 0, left: 0}

      describe ".height", ->
        it "is assigned based on the line height", ->
          presenter = buildPresenter()
          expect(getState(presenter).hiddenInput.height).toBe 10

          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(getState(presenter).hiddenInput.height).toBe 20

      describe ".width", ->
        it "is assigned based on the width of the character following the cursor", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setCursorBufferPosition([3, 6])
            presenter = buildPresenter()
            expect(getState(presenter).hiddenInput.width).toBe 10

            expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(15)
            expect(getState(presenter).hiddenInput.width).toBe 15

            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'storage.type.var.js'], 'r', 20)
              presenter.measurementsChanged()
            expect(getState(presenter).hiddenInput.width).toBe 20

        it "is 2px at the end of lines", ->
          presenter = buildPresenter()
          editor.setCursorBufferPosition([3, Infinity])
          expect(getState(presenter).hiddenInput.width).toBe 2

    describe ".content", ->
      describe ".maxHeight", ->
        it "changes based on boundingClientRect", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)

          expectStateUpdate presenter, ->
            presenter.setBoundingClientRect(left: 0, top: 0, height: 20, width: 0)
          expect(getState(presenter).content.maxHeight).toBe(20)

          expectStateUpdate presenter, ->
            presenter.setBoundingClientRect(left: 0, top: 0, height: 50, width: 0)
          expect(getState(presenter).content.maxHeight).toBe(50)

      describe ".scrollHeight", ->
        it "updates when new block decorations are measured, changed or destroyed", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(7)

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 35.8)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 50.3)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 95.2)

          linesHeight = editor.getScreenLineCount() * 10
          blockDecorationsHeight = Math.round(35.8 + 50.3 + 95.2)
          expect(getState(presenter).content.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 100.3)

          blockDecorationsHeight = Math.round(35.8 + 100.3 + 95.2)
          expect(getState(presenter).content.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

          waitsForStateToUpdate presenter, -> blockDecoration3.destroy()
          runs ->
            blockDecorationsHeight = Math.round(35.8 + 100.3)
            expect(getState(presenter).content.scrollHeight).toBe(linesHeight + blockDecorationsHeight)

        it "is initialized based on the lineHeight, the number of lines, and the height", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(getState(presenter).content.scrollHeight).toBe editor.getScreenLineCount() * 10

          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 500)
          expect(getState(presenter).content.scrollHeight).toBe 500

        it "updates when the ::lineHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(getState(presenter).content.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(getState(presenter).content.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
          expect(getState(presenter).content.scrollHeight).toBe 500

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(getState(presenter).content.scrollHeight).toBe presenter.contentHeight

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
          expect(getState(presenter).content.scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(getState(presenter).content.scrollHeight).toBe presenter.contentHeight

      describe ".scrollWidth", ->
        it "is initialized as the max of the computed clientWidth and the width of the longest line", ->
          maxLineLength = editor.getMaxScreenLineLength()

          presenter = buildPresenter(explicitHeight: 100, contentFrameWidth: 50, baseCharacterWidth: 10, verticalScrollbarWidth: 10)
          expect(getState(presenter).content.scrollWidth).toBe 10 * maxLineLength + 1

          presenter = buildPresenter(explicitHeight: 100, contentFrameWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10, verticalScrollbarWidth: 10)
          expect(getState(presenter).content.scrollWidth).toBe 10 * maxLineLength + 20 - 10 # subtract vertical scrollbar width

        describe "when the longest screen row is the first one and it's hidden", ->
          it "doesn't compute an invalid value (regression)", ->
            presenter = buildPresenter(tileSize: 2, contentFrameWidth: 10, explicitHeight: 20)
            editor.setText """
            a very long long long long long long line
            b
            c
            d
            e
            """

            expectStateUpdate presenter, -> presenter.setScrollTop(40)
            expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "updates when the ::contentFrameWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(getState(presenter).content.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setContentFrameWidth(10 * maxLineLength + 20)
          expect(getState(presenter).content.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when character widths change", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            maxLineLength = editor.getMaxScreenLineLength()
            presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

            expect(getState(presenter).content.scrollWidth).toBe 10 * maxLineLength + 1
            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'meta.method-call.js', 'support.function.js'], 'p', 20)
              presenter.measurementsChanged()
            expect(getState(presenter).content.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

        it "updates when ::softWrapped changes on the editor", ->
          presenter = buildPresenter(contentFrameWidth: 470, baseCharacterWidth: 10)
          expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
          expectStateUpdate presenter, -> editor.setSoftWrapped(true)
          expect(getState(presenter).horizontalScrollbar.scrollWidth).toBe presenter.clientWidth
          expectStateUpdate presenter, -> editor.setSoftWrapped(false)
          expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "updates when the longest line changes", ->
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([editor.getLongestScreenRow(), 0])
          expectStateUpdate presenter, -> editor.insertText('xyz')

          expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "isn't clipped to 0 when the longest line is folded (regression)", ->
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)
          editor.foldBufferRow(0)
          expect(getState(presenter).content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

      describe ".scrollTop", ->
        it "doesn't get stuck when repeatedly setting the same non-integer position in a scroll event listener", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 20)
          expect(getState(presenter).content.scrollTop).toBe(0)

          presenter.onDidChangeScrollTop ->
            presenter.setScrollTop(1.5)
            getState(presenter) # trigger scroll update

          presenter.setScrollTop(1.5)
          getState(presenter) # trigger scroll update

          expect(presenter.getScrollTop()).toBe(2)
          expect(presenter.getRealScrollTop()).toBe(1.5)

        it "changes based on the scroll operation that was performed last", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 20)
          expect(getState(presenter).content.scrollTop).toBe(0)

          presenter.setScrollTop(20)
          editor.setCursorBufferPosition([5, 0])

          expect(getState(presenter).content.scrollTop).toBe(50)

          editor.setCursorBufferPosition([8, 0])
          presenter.setScrollTop(10)

          expect(getState(presenter).content.scrollTop).toBe(10)

        it "corresponds to the passed logical coordinates when building the presenter", ->
          editor.setFirstVisibleScreenRow(4)
          presenter = buildPresenter(lineHeight: 10, explicitHeight: 20)
          expect(getState(presenter).content.scrollTop).toBe(40)

        it "tracks the value of ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, lineHeight: 10, explicitHeight: 20)
          expect(getState(presenter).content.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(getState(presenter).content.scrollTop).toBe 50

        it "keeps the model up to date with the corresponding logical coordinates", ->
          presenter = buildPresenter(scrollTop: 0, explicitHeight: 20, horizontalScrollbarHeight: 10, lineHeight: 10)

          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          getState(presenter) # commits scroll position
          expect(editor.getFirstVisibleScreenRow()).toBe 5

          expectStateUpdate presenter, -> presenter.setScrollTop(57)
          getState(presenter) # commits scroll position
          expect(editor.getFirstVisibleScreenRow()).toBe 6

        it "updates when the model's scroll position is changed directly", ->
          presenter = buildPresenter(scrollTop: 0, explicitHeight: 20, horizontalScrollbarHeight: 10, lineHeight: 10)
          expectStateUpdate presenter, -> editor.setFirstVisibleScreenRow(1)
          expect(getState(presenter).content.scrollTop).toBe 10

        it "reassigns the scrollTop if it exceeds the max possible value after lines are removed", ->
          presenter = buildPresenter(scrollTop: 80, lineHeight: 10, explicitHeight: 50, horizontalScrollbarHeight: 0)
          expect(getState(presenter).content.scrollTop).toBe(80)
          buffer.deleteRows(10, 9, 8)
          expect(getState(presenter).content.scrollTop).toBe(60)

        it "is always rounded to the nearest integer", ->
          presenter = buildPresenter(scrollTop: 10, lineHeight: 10, explicitHeight: 20)
          expect(getState(presenter).content.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(11.4)
          expect(getState(presenter).content.scrollTop).toBe 11
          expectStateUpdate presenter, -> presenter.setScrollTop(12.6)
          expect(getState(presenter).content.scrollTop).toBe 13

        it "scrolls down automatically when the model is changed", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 20)

          editor.setText("")
          editor.insertNewline()
          expect(getState(presenter).content.scrollTop).toBe(0)

          editor.insertNewline()
          expect(getState(presenter).content.scrollTop).toBe(10)

          editor.insertNewline()
          expect(getState(presenter).content.scrollTop).toBe(20)

        it "never exceeds the computed scroll height minus the computed client height", ->
          didChangeScrollTopSpy = jasmine.createSpy()
          presenter = buildPresenter(scrollTop: 10, lineHeight: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          presenter.onDidChangeScrollTop(didChangeScrollTopSpy)

          expectStateUpdate presenter, -> presenter.setScrollTop(100)
          expect(getState(presenter).content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
          expect(presenter.getRealScrollTop()).toBe presenter.scrollHeight - presenter.clientHeight
          expect(didChangeScrollTopSpy).toHaveBeenCalledWith presenter.scrollHeight - presenter.clientHeight

          didChangeScrollTopSpy.reset()
          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(getState(presenter).content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
          expect(presenter.getRealScrollTop()).toBe presenter.scrollHeight - presenter.clientHeight
          expect(didChangeScrollTopSpy).toHaveBeenCalledWith presenter.scrollHeight - presenter.clientHeight

          didChangeScrollTopSpy.reset()
          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
          expect(getState(presenter).content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
          expect(presenter.getRealScrollTop()).toBe presenter.scrollHeight - presenter.clientHeight
          expect(didChangeScrollTopSpy).toHaveBeenCalledWith presenter.scrollHeight - presenter.clientHeight

          didChangeScrollTopSpy.reset()
          expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
          expect(getState(presenter).content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
          expect(presenter.getRealScrollTop()).toBe presenter.scrollHeight - presenter.clientHeight
          expect(didChangeScrollTopSpy).toHaveBeenCalledWith presenter.scrollHeight - presenter.clientHeight

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollTopBefore = getState(presenter).verticalScrollbar.scrollTop
          didChangeScrollTopSpy.reset()
          expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
          expect(getState(presenter).content.scrollTop).toBe scrollTopBefore
          expect(presenter.getRealScrollTop()).toBe scrollTopBefore
          expect(didChangeScrollTopSpy).not.toHaveBeenCalled()

        it "never goes negative", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(-100)
          expect(getState(presenter).content.scrollTop).toBe 0

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(getState(presenter).content.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

          atom.config.set("editor.scrollPastEnd", true)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(getState(presenter).content.scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(getState(presenter).content.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

      describe ".scrollLeft", ->
        it "doesn't get stuck when repeatedly setting the same non-integer position in a scroll event listener", ->
          presenter = buildPresenter(scrollLeft: 0, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 10)
          expect(getState(presenter).content.scrollLeft).toBe(0)

          presenter.onDidChangeScrollLeft ->
            presenter.setScrollLeft(1.5)
            getState(presenter) # trigger scroll update

          presenter.setScrollLeft(1.5)
          getState(presenter) # trigger scroll update

          expect(presenter.getScrollLeft()).toBe(2)
          expect(presenter.getRealScrollLeft()).toBe(1.5)

        it "changes based on the scroll operation that was performed last", ->
          presenter = buildPresenter(scrollLeft: 0, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 10)
          expect(getState(presenter).content.scrollLeft).toBe(0)

          presenter.setScrollLeft(20)
          editor.setCursorBufferPosition([0, 9])

          expect(getState(presenter).content.scrollLeft).toBe(90)

          editor.setCursorBufferPosition([0, 18])
          presenter.setScrollLeft(50)

          expect(getState(presenter).content.scrollLeft).toBe(50)

        it "corresponds to the passed logical coordinates when building the presenter", ->
          editor.setFirstVisibleScreenColumn(3)
          presenter = buildPresenter(lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(getState(presenter).content.scrollLeft).toBe(30)

        it "tracks the value of ::scrollLeft", ->
          presenter = buildPresenter(scrollLeft: 10, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(getState(presenter).content.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          expect(getState(presenter).content.scrollLeft).toBe 50

        it "keeps the model up to date with the corresponding logical coordinates", ->
          presenter = buildPresenter(scrollLeft: 0, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)

          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          getState(presenter) # commits scroll position
          expect(editor.getFirstVisibleScreenColumn()).toBe 5

          expectStateUpdate presenter, -> presenter.setScrollLeft(57)
          getState(presenter) # commits scroll position
          expect(editor.getFirstVisibleScreenColumn()).toBe 6

        it "is always rounded to the nearest integer", ->
          presenter = buildPresenter(scrollLeft: 10, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(getState(presenter).content.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(11.4)
          expect(getState(presenter).content.scrollLeft).toBe 11
          expectStateUpdate presenter, -> presenter.setScrollLeft(12.6)
          expect(getState(presenter).content.scrollLeft).toBe 13

        it "never exceeds the computed scrollWidth minus the computed clientWidth", ->
          didChangeScrollLeftSpy = jasmine.createSpy()
          presenter = buildPresenter(scrollLeft: 10, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          presenter.onDidChangeScrollLeft(didChangeScrollLeftSpy)

          expectStateUpdate presenter, -> presenter.setScrollLeft(300)
          expect(getState(presenter).content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth
          expect(presenter.getRealScrollLeft()).toBe presenter.scrollWidth - presenter.clientWidth
          expect(didChangeScrollLeftSpy).toHaveBeenCalledWith presenter.scrollWidth - presenter.clientWidth

          didChangeScrollLeftSpy.reset()
          expectStateUpdate presenter, -> presenter.setContentFrameWidth(600)
          expect(getState(presenter).content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth
          expect(presenter.getRealScrollLeft()).toBe presenter.scrollWidth - presenter.clientWidth
          expect(didChangeScrollLeftSpy).toHaveBeenCalledWith presenter.scrollWidth - presenter.clientWidth

          didChangeScrollLeftSpy.reset()
          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(5)
          expect(getState(presenter).content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth
          expect(presenter.getRealScrollLeft()).toBe presenter.scrollWidth - presenter.clientWidth
          expect(didChangeScrollLeftSpy).toHaveBeenCalledWith presenter.scrollWidth - presenter.clientWidth

          didChangeScrollLeftSpy.reset()
          expectStateUpdate presenter, -> editor.getBuffer().delete([[6, 0], [6, Infinity]])
          expect(getState(presenter).content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth
          expect(presenter.getRealScrollLeft()).toBe presenter.scrollWidth - presenter.clientWidth
          expect(didChangeScrollLeftSpy).toHaveBeenCalledWith presenter.scrollWidth - presenter.clientWidth

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollLeftBefore = getState(presenter).content.scrollLeft
          didChangeScrollLeftSpy.reset()
          expectStateUpdate presenter, -> editor.getBuffer().insert([6, 0], new Array(100).join('x'))
          expect(getState(presenter).content.scrollLeft).toBe scrollLeftBefore
          expect(presenter.getRealScrollLeft()).toBe scrollLeftBefore
          expect(didChangeScrollLeftSpy).not.toHaveBeenCalled()

        it "never goes negative", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(-300)
          expect(getState(presenter).content.scrollLeft).toBe 0

      describe ".backgroundColor", ->
        it "is assigned to ::backgroundColor unless the editor is mini", ->
          presenter = buildPresenter()
          presenter.setBackgroundColor('rgba(255, 0, 0, 0)')
          expect(getState(presenter).content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'

          editor.setMini(true)
          presenter = buildPresenter()
          presenter.setBackgroundColor('rgba(255, 0, 0, 0)')
          expect(getState(presenter).content.backgroundColor).toBeNull()

        it "updates when ::backgroundColor changes", ->
          presenter = buildPresenter()
          presenter.setBackgroundColor('rgba(255, 0, 0, 0)')
          expect(getState(presenter).content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> presenter.setBackgroundColor('rgba(0, 0, 255, 0)')
          expect(getState(presenter).content.backgroundColor).toBe 'rgba(0, 0, 255, 0)'

        it "updates when ::mini changes", ->
          presenter = buildPresenter()
          presenter.setBackgroundColor('rgba(255, 0, 0, 0)')
          expect(getState(presenter).content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> editor.setMini(true)
          expect(getState(presenter).content.backgroundColor).toBeNull()

      describe ".placeholderText", ->
        it "is present when the editor has no text", ->
          editor.setPlaceholderText("the-placeholder-text")
          presenter = buildPresenter()
          expect(getState(presenter).content.placeholderText).toBeNull()

          expectStateUpdate presenter, -> editor.setText("")
          expect(getState(presenter).content.placeholderText).toBe "the-placeholder-text"

          expectStateUpdate presenter, -> editor.setPlaceholderText("new-placeholder-text")
          expect(getState(presenter).content.placeholderText).toBe "new-placeholder-text"

      describe ".tiles", ->
        lineStateForScreenRow = (presenter, row) ->
          tilesState = getState(presenter).content.tiles
          lineId = presenter.linesByScreenRow.get(row)?.id
          tilesState[presenter.tileForRow(row)]?.lines[lineId]

        tagsForCodes = (presenter, tagCodes) ->
          openTags = []
          closeTags = []
          for tagCode in tagCodes when tagCode < 0 # skip text codes
            if presenter.isOpenTagCode(tagCode)
              openTags.push(presenter.tagForCode(tagCode))
            else
              closeTags.push(presenter.tagForCode(tagCode))
          {openTags, closeTags}

        tiledContentContract (presenter) -> getState(presenter).content

        describe "[tileId].lines[lineId]", -> # line state objects
          it "includes the state for visible lines in a tile", ->
            presenter = buildPresenter(explicitHeight: 3, scrollTop: 4, lineHeight: 1, tileSize: 3, stoppedScrollingDelay: 200)
            presenter.setExplicitHeight(3)

            expect(lineStateForScreenRow(presenter, 2)).toBeUndefined()
            expectValues lineStateForScreenRow(presenter, 3), {screenRow: 3, tagCodes: editor.screenLineForScreenRow(3).tagCodes}
            expectValues lineStateForScreenRow(presenter, 4), {screenRow: 4, tagCodes: editor.screenLineForScreenRow(4).tagCodes}
            expectValues lineStateForScreenRow(presenter, 5), {screenRow: 5, tagCodes: editor.screenLineForScreenRow(5).tagCodes}
            expectValues lineStateForScreenRow(presenter, 6), {screenRow: 6, tagCodes: editor.screenLineForScreenRow(6).tagCodes}
            expectValues lineStateForScreenRow(presenter, 7), {screenRow: 7, tagCodes: editor.screenLineForScreenRow(7).tagCodes}
            expectValues lineStateForScreenRow(presenter, 8), {screenRow: 8, tagCodes: editor.screenLineForScreenRow(8).tagCodes}
            expect(lineStateForScreenRow(presenter, 9)).toBeUndefined()

          it "updates when the editor's content changes", ->
            presenter = buildPresenter(explicitHeight: 25, scrollTop: 10, lineHeight: 10, tileSize: 2)

            expectStateUpdate presenter, -> buffer.insert([2, 0], "hello\nworld\n")

            expectValues lineStateForScreenRow(presenter, 1), {screenRow: 1, tagCodes: editor.screenLineForScreenRow(1).tagCodes}
            expectValues lineStateForScreenRow(presenter, 2), {screenRow: 2, tagCodes: editor.screenLineForScreenRow(2).tagCodes}
            expectValues lineStateForScreenRow(presenter, 3), {screenRow: 3, tagCodes: editor.screenLineForScreenRow(3).tagCodes}

          it "includes the .endOfLineInvisibles if the editor.showInvisibles config option is true", ->
            editor.setText("hello\nworld\r\n")
            presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10)
            expect(tagsForCodes(presenter, lineStateForScreenRow(presenter, 0).tagCodes).openTags).not.toContain('invisible-character eol')
            expect(tagsForCodes(presenter, lineStateForScreenRow(presenter, 1).tagCodes).openTags).not.toContain('invisible-character eol')

            editor.setShowInvisibles(true)
            presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10)
            expect(tagsForCodes(presenter, lineStateForScreenRow(presenter, 0).tagCodes).openTags).toContain('invisible-character eol')
            expect(tagsForCodes(presenter, lineStateForScreenRow(presenter, 1).tagCodes).openTags).toContain('invisible-character eol')

          describe ".blockDecorations", ->
            it "contains all block decorations that are present before/after a line, both initially and when decorations change", ->
              blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
              presenter = buildPresenter()
              blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
              blockDecoration3 = addBlockDecorationBeforeScreenRow(7)
              blockDecoration4 = null

              waitsForStateToUpdate presenter, ->
                blockDecoration4 = addBlockDecorationAfterScreenRow(7)

              runs ->
                expect(lineStateForScreenRow(presenter, 0).precedingBlockDecorations).toEqual([blockDecoration1])
                expect(lineStateForScreenRow(presenter, 0).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).precedingBlockDecorations).toEqual([blockDecoration2])
                expect(lineStateForScreenRow(presenter, 3).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).precedingBlockDecorations).toEqual([blockDecoration3])
                expect(lineStateForScreenRow(presenter, 7).followingBlockDecorations).toEqual([blockDecoration4])
                expect(lineStateForScreenRow(presenter, 8).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 9).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 9).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).followingBlockDecorations).toEqual([])

              waitsForStateToUpdate presenter, ->
                blockDecoration1.getMarker().setHeadBufferPosition([1, 0])
                blockDecoration2.getMarker().setHeadBufferPosition([9, 0])
                blockDecoration3.getMarker().setHeadBufferPosition([9, 0])
                blockDecoration4.getMarker().setHeadBufferPosition([8, 0])

              runs ->
                expect(lineStateForScreenRow(presenter, 0).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 0).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).precedingBlockDecorations).toEqual([blockDecoration1])
                expect(lineStateForScreenRow(presenter, 1).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).followingBlockDecorations).toEqual([blockDecoration4])
                expect(lineStateForScreenRow(presenter, 9).precedingBlockDecorations).toEqual([blockDecoration2, blockDecoration3])
                expect(lineStateForScreenRow(presenter, 9).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).followingBlockDecorations).toEqual([])

              waitsForStateToUpdate presenter, ->
                blockDecoration4.destroy()
                blockDecoration3.destroy()
                blockDecoration1.getMarker().setHeadBufferPosition([0, 0])

              runs ->
                expect(lineStateForScreenRow(presenter, 0).precedingBlockDecorations).toEqual([blockDecoration1])
                expect(lineStateForScreenRow(presenter, 0).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 9).precedingBlockDecorations).toEqual([blockDecoration2])
                expect(lineStateForScreenRow(presenter, 9).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).followingBlockDecorations).toEqual([])

              waitsForStateToUpdate presenter, ->
                editor.setCursorBufferPosition([0, 0])
                editor.insertNewline()

              runs ->
                expect(lineStateForScreenRow(presenter, 0).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 0).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 1).precedingBlockDecorations).toEqual([blockDecoration1])
                expect(lineStateForScreenRow(presenter, 1).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 2).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 3).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 4).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 5).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 6).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 7).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 8).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 9).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 9).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 10).precedingBlockDecorations).toEqual([blockDecoration2])
                expect(lineStateForScreenRow(presenter, 10).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 11).followingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).precedingBlockDecorations).toEqual([])
                expect(lineStateForScreenRow(presenter, 12).followingBlockDecorations).toEqual([])

            it "inserts block decorations before the line if not specified otherwise", ->
              blockDecoration = editor.decorateMarker(editor.markScreenPosition([4, 0]), {type: "block"})
              presenter = buildPresenter()

              expect(lineStateForScreenRow(presenter, 4).precedingBlockDecorations).toEqual [blockDecoration]
              expect(lineStateForScreenRow(presenter, 4).followingBlockDecorations).toEqual []

          describe ".decorationClasses", ->
            it "adds decoration classes to the relevant line state objects, both initially and when decorations change", ->
              marker1 = editor.addMarkerLayer(maintainHistory: true).markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration1 = editor.decorateMarker(marker1, type: 'line', class: 'a')
              presenter = buildPresenter()
              marker2 = editor.addMarkerLayer(maintainHistory: true).markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration2 = null

              waitsForStateToUpdate presenter, -> decoration2 = editor.decorateMarker(marker2, type: 'line', class: 'b')
              runs ->
                expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
              runs ->
                expect(marker1.isValid()).toBe false
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> editor.undo()
              runs ->
                expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
              runs ->
                expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
                expect(lineStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
                expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> decoration1.destroy()
              runs ->
                expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
                expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> marker2.destroy()
              runs ->
                expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            it "honors the 'onlyEmpty' option on line decorations", ->
              presenter = buildPresenter()
              marker = editor.markBufferRange([[4, 0], [6, 1]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyEmpty: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, -> marker.clearTail()

              runs ->
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            it "honors the 'onlyNonEmpty' option on line decorations", ->
              presenter = buildPresenter()
              marker = editor.markBufferRange([[4, 0], [6, 2]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyNonEmpty: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

              waitsForStateToUpdate presenter, -> marker.clearTail()

              runs ->
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "honors the 'onlyHead' option on line decorations", ->
              presenter = buildPresenter()
              waitsForStateToUpdate presenter, ->
                marker = editor.markBufferRange([[4, 0], [6, 2]])
                editor.decorateMarker(marker, type: 'line', class: 'a', onlyHead: true)

              runs ->
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            it "does not decorate the last line of a non-empty line decoration range if it ends at column 0", ->
              presenter = buildPresenter()
              waitsForStateToUpdate presenter, ->
                marker = editor.markBufferRange([[4, 0], [6, 0]])
                editor.decorateMarker(marker, type: 'line', class: 'a')

              runs ->
                expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
                expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
                expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "does not apply line decorations to mini editors", ->
              editor.setMini(true)
              presenter = buildPresenter(explicitHeight: 10)

              waitsForStateToUpdate presenter, ->
                marker = editor.markBufferRange([[0, 0], [0, 0]])
                decoration = editor.decorateMarker(marker, type: 'line', class: 'a')

              runs ->
                expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

                expectStateUpdate presenter, -> editor.setMini(false)
                expect(lineStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'a']

                expectStateUpdate presenter, -> editor.setMini(true)
                expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

            it "only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
              editor.setText("a line that wraps, ok")
              editor.setSoftWrapped(true)
              editor.setDefaultCharWidth(1)
              editor.setEditorWidthInChars(16)
              marker = editor.markBufferRange([[0, 0], [0, 2]])
              editor.decorateMarker(marker, type: 'line', class: 'a')
              presenter = buildPresenter(explicitHeight: 10)

              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

              waitsForStateToUpdate presenter, ->
                marker.setBufferRange([[0, 0], [0, Infinity]])

              runs ->
                expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
                expect(lineStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

      describe ".cursors", ->
        stateForCursor = (presenter, cursorIndex) ->
          getState(presenter).content.cursors[presenter.model.getCursors()[cursorIndex].id]

        it "contains pixelRects for empty selections that are visible on screen", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toEqual {top: 0, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10 - 20, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toBeUndefined()

        it "is empty until all of the required measurements are assigned", ->
          presenter = buildPresenterWithoutMeasurements()
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setExplicitHeight(25)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setLineHeight(10)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setScrollTop(0)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setBaseCharacterWidth(8)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setBoundingClientRect(top: 0, left: 0, width: 500, height: 130)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setWindowSize(500, 130)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setVerticalScrollbarWidth(10)
          expect(getState(presenter).content.cursors).toEqual({})

          presenter.setHorizontalScrollbarHeight(10)
          expect(getState(presenter).content.cursors).not.toEqual({})

        it "updates when block decorations change", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = buildPresenter(explicitHeight: 80, scrollTop: 0)

          expect(stateForCursor(presenter, 0)).toEqual {top: 10, left: 2 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 1)).toEqual {top: 20, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 10, left: 4 * 10, width: 10, height: 10}

          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          blockDecoration2 = addBlockDecorationAfterScreenRow(1)

          waitsForStateToUpdate presenter, ->
            presenter.setBlockDecorationDimensions(blockDecoration1, 0, 30)
            presenter.setBlockDecorationDimensions(blockDecoration2, 0, 10)

          runs ->
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10 + 30, left: 2 * 10, width: 10, height: 10}
            expect(stateForCursor(presenter, 1)).toEqual {top: 2 * 10 + 30 + 10, left: 4 * 10, width: 10, height: 10}
            expect(stateForCursor(presenter, 2)).toBeUndefined()
            expect(stateForCursor(presenter, 3)).toBeUndefined()
            expect(stateForCursor(presenter, 4)).toBeUndefined()

          waitsForStateToUpdate presenter, ->
            blockDecoration2.destroy()
            editor.setCursorBufferPosition([0, 0])
            editor.insertNewline()
            editor.setCursorBufferPosition([0, 0])

          runs ->
            expect(stateForCursor(presenter, 0)).toEqual {top: 0, left: 0, width: 10, height: 10}

        it "considers block decorations to be before a line by default", ->
          editor.setCursorScreenPosition([4, 0])
          blockDecoration = editor.decorateMarker(editor.markScreenPosition([4, 0]), {type: "block"})
          presenter = buildPresenter()
          presenter.setBlockDecorationDimensions(blockDecoration, 0, 6)

          expect(stateForCursor(presenter, 0)).toEqual {top: 4 * 10 + 6, left: 0, width: 10, height: 10}

        it "updates when ::scrollTop changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expectStateUpdate presenter, -> presenter.setScrollTop(5 * 10)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toBeUndefined()
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 0, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 10 - 50, left: 4 * 10, width: 10, height: 10}

        it "updates when ::scrollTop changes after the model was changed", ->
          editor.setCursorBufferPosition([8, 22])
          presenter = buildPresenter(explicitHeight: 50, scrollTop: 10 * 8)

          expect(stateForCursor(presenter, 0)).toEqual {top: 0, left: 10 * 22, width: 10, height: 10}

          expectStateUpdate presenter, ->
            editor.getBuffer().deleteRow(12)
            editor.getBuffer().deleteRow(11)
            editor.getBuffer().deleteRow(10)

          expect(stateForCursor(presenter, 0)).toEqual {top: 20, left: 10 * 22, width: 10, height: 10}

        it "updates when ::explicitHeight changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20)

          expectStateUpdate presenter, -> presenter.setExplicitHeight(30)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toEqual {top: 0, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10 - 20, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20)

          expectStateUpdate presenter, -> presenter.setLineHeight(5)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toBeUndefined()
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5, left: 12 * 10, width: 10, height: 5}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 5 - 20, left: 4 * 10, width: 10, height: 5}

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setCursorBufferPosition([1, 4])
            presenter = buildPresenter(explicitHeight: 20)

            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'storage.type.var.js'], 'v', 20)
              presenter.measurementsChanged()
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10, left: (3 * 10) + 20, width: 10, height: 10}

            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'storage.type.var.js'], 'r', 20)
              presenter.measurementsChanged()
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10, left: (3 * 10) + 20, width: 20, height: 10}

        it "updates when cursors are added, moved, hidden, shown, or destroyed", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[3, 4], [3, 5]]
          ])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20)

          # moving into view
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          editor.getCursors()[0].setBufferPosition([2, 4])
          expect(stateForCursor(presenter, 0)).toEqual {top: 0, left: 4 * 10, width: 10, height: 10}

          # showing
          expectStateUpdate presenter, -> editor.getSelections()[1].clear()
          expect(stateForCursor(presenter, 1)).toEqual {top: 0, left: 5 * 10, width: 10, height: 10}

          # hiding
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[3, 4], [3, 5]])
          expect(stateForCursor(presenter, 1)).toBeUndefined()

          # moving out of view
          expectStateUpdate presenter, -> editor.getCursors()[0].setBufferPosition([10, 4])
          expect(stateForCursor(presenter, 0)).toBeUndefined()

          # adding
          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([4, 4])
          expect(stateForCursor(presenter, 2)).toEqual {top: 0, left: 4 * 10, width: 10, height: 10}

          # moving added cursor
          expectStateUpdate presenter, -> editor.getCursors()[2].setBufferPosition([4, 6])
          expect(stateForCursor(presenter, 2)).toEqual {top: 0, left: 6 * 10, width: 10, height: 10}

          # destroying
          destroyedCursor = editor.getCursors()[2]
          expectStateUpdate presenter, -> destroyedCursor.destroy()
          expect(getState(presenter).content.cursors[destroyedCursor.id]).toBeUndefined()

        it "makes cursors as wide as the ::baseCharacterWidth if they're at the end of a line", ->
          editor.setCursorBufferPosition([1, Infinity])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)
          expect(stateForCursor(presenter, 0).width).toBe 10

      describe ".cursorsVisible", ->
        it "alternates between true and false twice per ::cursorBlinkPeriod when the editor is focused", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = buildPresenter({cursorBlinkPeriod, cursorBlinkResumeDelay})
          presenter.setFocused(true)

          expect(getState(presenter).content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe true

          expectStateUpdate presenter, -> presenter.setFocused(false)
          expect(getState(presenter).content.cursorsVisible).toBe false
          advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false
          advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> presenter.setFocused(true)
          expect(getState(presenter).content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false

        it "stops alternating for ::cursorBlinkResumeDelay when a cursor moves or a cursor is added", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = buildPresenter({cursorBlinkPeriod, cursorBlinkResumeDelay})
          presenter.setFocused(true)

          expect(getState(presenter).content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> editor.moveRight()
          expect(getState(presenter).content.cursorsVisible).toBe true

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)

          expect(getState(presenter).content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([1, 0])
          expect(getState(presenter).content.cursorsVisible).toBe true

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)
          expect(getState(presenter).content.cursorsVisible).toBe false

      describe ".highlights", ->
        expectUndefinedStateForHighlight = (presenter, decoration) ->
          for tileId, tileState of getState(presenter).content.tiles
            state = stateForHighlightInTile(presenter, decoration, tileId)
            expect(state).toBeUndefined()

        stateForHighlightInTile = (presenter, decoration, tile) ->
          getState(presenter).content.tiles[tile]?.highlights[decoration.id]

        stateForSelectionInTile = (presenter, selectionIndex, tile) ->
          selection = presenter.model.getSelections()[selectionIndex]
          stateForHighlightInTile(presenter, selection.decoration, tile)

        expectUndefinedStateForSelection = (presenter, selectionIndex) ->
          for tileId, tileState of getState(presenter).content.tiles
            state = stateForSelectionInTile(presenter, selectionIndex, tileId)
            expect(state).toBeUndefined()

        it "contains states for highlights that are visible on screen", ->
          # off-screen above
          marker1 = editor.markBufferRange([[0, 0], [1, 0]])
          highlight1 = editor.decorateMarker(marker1, type: 'highlight', class: 'a')

          # partially off-screen above, 1 of 2 regions on screen
          marker2 = editor.markBufferRange([[1, 6], [2, 6]])
          highlight2 = editor.decorateMarker(marker2, type: 'highlight', class: 'b')

          # partially off-screen above, 2 of 3 regions on screen
          marker3 = editor.markBufferRange([[0, 6], [3, 6]])
          highlight3 = editor.decorateMarker(marker3, type: 'highlight', class: 'c')

          # on-screen, spans over 2 tiles
          marker4 = editor.markBufferRange([[2, 6], [4, 6]])
          highlight4 = editor.decorateMarker(marker4, type: 'highlight', class: 'd')

          # partially off-screen below, spans over 3 tiles, 2 of 3 regions on screen
          marker5 = editor.markBufferRange([[3, 6], [6, 6]])
          highlight5 = editor.decorateMarker(marker5, type: 'highlight', class: 'e')

          # partially off-screen below, 1 of 3 regions on screen
          marker6 = editor.markBufferRange([[5, 6], [7, 6]])
          highlight6 = editor.decorateMarker(marker6, type: 'highlight', class: 'f')

          # off-screen below
          marker7 = editor.markBufferRange([[6, 6], [7, 6]])
          highlight7 = editor.decorateMarker(marker7, type: 'highlight', class: 'g')

          # on-screen, empty
          marker8 = editor.markBufferRange([[2, 2], [2, 2]])
          highlight8 = editor.decorateMarker(marker8, type: 'highlight', class: 'h')

          # partially off-screen above, empty
          marker9 = editor.markBufferRange([[0, 0], [2, 0]], invalidate: 'touch')
          highlight9 = editor.decorateMarker(marker9, type: 'highlight', class: 'h')

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20, tileSize: 2)

          expectUndefinedStateForHighlight(presenter, highlight1)

          expectValues stateForHighlightInTile(presenter, highlight2, 2), {
            class: 'b'
            regions: [
              {top: 0, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlightInTile(presenter, highlight3, 2), {
            class: 'c'
            regions: [
              {top: 0, left: 0 * 10, right: 0, height: 1 * 10}
              {top: 10, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlightInTile(presenter, highlight4, 2), {
            class: 'd'
            regions: [
              {top: 0, left: 6 * 10, right: 0, height: 1 * 10}
              {top: 10, left: 0, right: 0, height: 1 * 10}
            ]
          }
          expectValues stateForHighlightInTile(presenter, highlight4, 4), {
            class: 'd'
            regions: [
              {top: 0, left: 0, width: 60, height: 1 * 10}
            ]
          }

          expectValues stateForHighlightInTile(presenter, highlight5, 2), {
            class: 'e'
            regions: [
              {top: 10, left: 6 * 10, right: 0, height: 1 * 10}
            ]
          }

          expectValues stateForHighlightInTile(presenter, highlight5, 4), {
            class: 'e'
            regions: [
              {top: 0, left: 0, right: 0, height: 1 * 10}
              {top: 10, left: 0, right: 0, height: 1 * 10}
            ]
          }

          expect(stateForHighlightInTile(presenter, highlight5, 6)).toBeUndefined()

          expectValues stateForHighlightInTile(presenter, highlight6, 4), {
            class: 'f'
            regions: [
              {top: 10, left: 6 * 10, right: 0, height: 1 * 10}
            ]
          }

          expect(stateForHighlightInTile(presenter, highlight6, 6)).toBeUndefined()

          expectUndefinedStateForHighlight(presenter, highlight7)
          expectUndefinedStateForHighlight(presenter, highlight8)
          expectUndefinedStateForHighlight(presenter, highlight9)

        it "is empty until all of the required measurements are assigned", ->
          editor.setSelectedBufferRanges([
            [[0, 2], [2, 4]],
          ])

          presenter = buildPresenterWithoutMeasurements(tileSize: 2)
          for tileId, tileState of getState(presenter).content.tiles
            expect(tileState.highlights).toEqual({})

          presenter.setExplicitHeight(25)
          for tileId, tileState of getState(presenter).content.tiles
            expect(tileState.highlights).toEqual({})

          presenter.setLineHeight(10)
          for tileId, tileState of getState(presenter).content.tiles
            expect(tileState.highlights).toEqual({})

          presenter.setScrollTop(0)
          for tileId, tileState of getState(presenter).content.tiles
            expect(tileState.highlights).toEqual({})

          presenter.setBaseCharacterWidth(8)
          assignedAnyHighlight = false
          for tileId, tileState of getState(presenter).content.tiles
            assignedAnyHighlight ||= _.isEqual(tileState.highlights, {})

          expect(assignedAnyHighlight).toBe(true)

        it "does not include highlights for invalid markers", ->
          marker = editor.markBufferRange([[2, 2], [2, 4]], invalidate: 'touch')
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'h')

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20, tileSize: 2)

          expect(stateForHighlightInTile(presenter, highlight, 2)).toBeDefined()

          expectStateUpdate presenter, -> editor.getBuffer().insert([2, 2], "stuff")

          expectUndefinedStateForHighlight(presenter, highlight)

        it "does not include highlights that end before the first visible row", ->
          editor.setText("Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat.")
          editor.setSoftWrapped(true)
          editor.setWidth(100, true)
          editor.setDefaultCharWidth(10)

          marker = editor.markBufferRange([[0, 0], [0, 4]], invalidate: 'never')
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 10, tileSize: 2)

          expect(stateForHighlightInTile(presenter, highlight, 0)).toBeUndefined()

        it "updates when ::scrollTop changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20, tileSize: 2)

          expectUndefinedStateForSelection(presenter, 0)
          expectStateUpdate presenter, -> presenter.setScrollTop(5 * 10)
          expect(stateForSelectionInTile(presenter, 0, 6)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setScrollTop(2 * 10)
          expectUndefinedStateForSelection(presenter, 0)

        it "updates when ::explicitHeight changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20, tileSize: 2)

          expectUndefinedStateForSelection(presenter, 0)
          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(stateForSelectionInTile(presenter, 0, 6)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setExplicitHeight(20)
          expectUndefinedStateForSelection(presenter, 0)

        it "updates when ::lineHeight changes", ->
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 4]],
            [[3, 4], [3, 6]],
          ])

          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0, tileSize: 2)

          expectValues stateForSelectionInTile(presenter, 0, 2), {
            regions: [
              {top: 0, left: 2 * 10, width: 2 * 10, height: 10}
            ]
          }
          expectUndefinedStateForSelection(presenter, 1)

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues stateForSelectionInTile(presenter, 0, 2), {
            regions: [
              {top: 0, left: 2 * 10, width: 2 * 10, height: 5}
            ]
          }

          expectValues stateForSelectionInTile(presenter, 1, 2), {
            regions: [
              {top: 5, left: 4 * 10, width: 2 * 10, height: 5}
            ]
          }

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setSelectedBufferRanges([
              [[2, 4], [2, 6]],
            ])

            presenter = buildPresenter(explicitHeight: 20, scrollTop: 0, tileSize: 2)

            expectValues stateForSelectionInTile(presenter, 0, 2), {
              regions: [{top: 0, left: 4 * 10, width: 2 * 10, height: 10}]
            }
            expectStateUpdate presenter, ->
              presenter.getLinesYardstick().setScopedCharacterWidth(['source.js', 'keyword.control.js'], 'i', 20)
              presenter.measurementsChanged()
            expectValues stateForSelectionInTile(presenter, 0, 2), {
              regions: [{top: 0, left: 4 * 10, width: 20 + 10, height: 10}]
            }

        it "updates when highlight decorations are added, moved, hidden, shown, or destroyed", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 4]],
            [[3, 4], [3, 6]]
          ])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0, tileSize: 2)

          expectValues stateForSelectionInTile(presenter, 0, 0), {
            regions: [{top: 10, left: 2 * 10, width: 2 * 10, height: 10}]
          }
          expectUndefinedStateForSelection(presenter, 1)

          # moving into view
          waitsForStateToUpdate presenter, -> editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]], autoscroll: false)
          runs ->
            expectValues stateForSelectionInTile(presenter, 1, 2), {
              regions: [{top: 0, left: 4 * 10, width: 2 * 10, height: 10}]
            }

          # becoming empty
          runs ->
            editor.getSelections()[1].clear(autoscroll: false)
          waitsForStateToUpdate presenter
          runs ->
            expectUndefinedStateForSelection(presenter, 1)

          # becoming non-empty
          runs ->
            editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]], autoscroll: false)
          waitsForStateToUpdate presenter
          runs ->
            expectValues stateForSelectionInTile(presenter, 1, 2), {
              regions: [{top: 0, left: 4 * 10, width: 2 * 10, height: 10}]
            }

          # moving out of view
          runs ->
            editor.getSelections()[1].setBufferRange([[3, 4], [3, 6]], autoscroll: false)
          waitsForStateToUpdate presenter
          runs ->
            expectUndefinedStateForSelection(presenter, 1)

          # adding
          runs -> editor.addSelectionForBufferRange([[1, 4], [1, 6]], autoscroll: false)
          waitsForStateToUpdate presenter
          runs ->
            expectValues stateForSelectionInTile(presenter, 2, 0), {
              regions: [{top: 10, left: 4 * 10, width: 2 * 10, height: 10}]
            }

          # moving added selection
          runs ->
            editor.getSelections()[2].setBufferRange([[1, 4], [1, 8]], autoscroll: false)
          waitsForStateToUpdate presenter

          destroyedSelection = null
          runs ->
            expectValues stateForSelectionInTile(presenter, 2, 0), {
              regions: [{top: 10, left: 4 * 10, width: 4 * 10, height: 10}]
            }

            # destroying
            destroyedSelection = editor.getSelections()[2]

          waitsForStateToUpdate presenter, -> destroyedSelection.destroy()
          runs ->
            expectUndefinedStateForHighlight(presenter, destroyedSelection.decoration)

        it "updates when highlight decorations' properties are updated", ->
          marker = editor.markBufferPosition([2, 2])
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20, tileSize: 2)

          expectUndefinedStateForHighlight(presenter, highlight)

          waitsForStateToUpdate presenter, ->
            marker.setBufferRange([[2, 2], [2, 4]])
            highlight.setProperties(class: 'b', type: 'highlight')

          runs ->
            expectValues stateForHighlightInTile(presenter, highlight, 2), {class: 'b'}

        it "increments the .flashCount and sets the .flashClass and .flashDuration when the highlight model flashes", ->
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20, tileSize: 2)

          marker = editor.markBufferPosition([2, 2])
          highlight = null
          waitsForStateToUpdate presenter, ->
            highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')
            marker.setBufferRange([[2, 2], [5, 2]])
            highlight.flash('b', 500)
          runs ->
            expectValues stateForHighlightInTile(presenter, highlight, 2), {
              flashClass: 'b'
              flashDuration: 500
              flashCount: 1
            }
            expectValues stateForHighlightInTile(presenter, highlight, 4), {
              flashClass: 'b'
              flashDuration: 500
              flashCount: 1
            }

          waitsForStateToUpdate presenter, -> highlight.flash('c', 600)
          runs ->
            expectValues stateForHighlightInTile(presenter, highlight, 2), {
              flashClass: 'c'
              flashDuration: 600
              flashCount: 2
            }
            expectValues stateForHighlightInTile(presenter, highlight, 4), {
              flashClass: 'c'
              flashDuration: 600
              flashCount: 2
            }

      describe ".blockDecorations", ->
        stateForBlockDecoration = (presenter, decoration) ->
          getState(presenter).content.blockDecorations[decoration.id]

        it "contains state for measured block decorations that are not visible when they are on ::mouseWheelScreenRow", ->
          blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
          presenter = buildPresenter(explicitHeight: 30, lineHeight: 10, tileSize: 2, scrollTop: 0, stoppedScrollingDelay: 200)
          getState(presenter) # flush pending state
          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 0)

          presenter.setScrollTop(100)
          presenter.setMouseWheelScreenRow(0)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 0
            isVisible: true
          }

          advanceClock(presenter.stoppedScrollingDelay)

          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()

        it "invalidates block decorations that intersect a change in the buffer", ->
          blockDecoration1 = addBlockDecorationBeforeScreenRow(9)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(10)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(11)
          presenter = buildPresenter(explicitHeight: 30, lineHeight: 10, tileSize: 2, scrollTop: 0)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 9
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration2), {
            decoration: blockDecoration2
            screenRow: 10
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration3), {
            decoration: blockDecoration3
            screenRow: 11
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 10)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 10)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 10)
          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()
          expect(stateForBlockDecoration(presenter, blockDecoration2)).toBeUndefined()
          expect(stateForBlockDecoration(presenter, blockDecoration3)).toBeUndefined()

          editor.setSelectedScreenRange([[10, 0], [12, 0]])
          editor.delete()
          presenter.setScrollTop(0) # deleting the buffer causes the editor to autoscroll

          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()
          expectValues stateForBlockDecoration(presenter, blockDecoration2), {
            decoration: blockDecoration2
            screenRow: 10
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration3), {
            decoration: blockDecoration3
            screenRow: 10
            isVisible: false
          }

        it "invalidates all block decorations when content frame width, window size or bounding client rect change", ->
          blockDecoration1 = addBlockDecorationBeforeScreenRow(11)
          presenter = buildPresenter(explicitHeight: 30, lineHeight: 10, tileSize: 2, scrollTop: 0)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 11
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 10)
          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()

          presenter.setBoundingClientRect({top: 0, left: 0, width: 50, height: 30})
          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 11
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 20)
          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()

          presenter.setContentFrameWidth(100)
          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 11
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 20)
          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()

          presenter.setWindowSize(100, 200)
          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 11
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 20)
          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()

        it "contains state for on-screen and unmeasured block decorations, both initially and when they are updated or destroyed", ->
          item = {}
          blockDecoration1 = addBlockDecorationBeforeScreenRow(0, item)
          blockDecoration2 = addBlockDecorationBeforeScreenRow(4, item)
          blockDecoration3 = addBlockDecorationBeforeScreenRow(4, item)
          blockDecoration4 = addBlockDecorationBeforeScreenRow(10, item)
          presenter = buildPresenter(explicitHeight: 30, lineHeight: 10, tileSize: 2, scrollTop: 0)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 0
            isVisible: true
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration2), {
            decoration: blockDecoration2
            screenRow: 4
            isVisible: true
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration3), {
            decoration: blockDecoration3
            screenRow: 4
            isVisible: true
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration4), {
            decoration: blockDecoration4
            screenRow: 10
            isVisible: false
          }

          presenter.setBlockDecorationDimensions(blockDecoration1, 0, 10)
          presenter.setBlockDecorationDimensions(blockDecoration4, 0, 20)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 0
            isVisible: true
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration2), {
            decoration: blockDecoration2
            screenRow: 4
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration3), {
            decoration: blockDecoration3
            screenRow: 4
            isVisible: false
          }
          expect(stateForBlockDecoration(presenter, blockDecoration4)).toBeUndefined()

          blockDecoration3.getMarker().setHeadScreenPosition([5, 0])
          presenter.setScrollTop(90)

          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()
          expectValues stateForBlockDecoration(presenter, blockDecoration2), {
            decoration: blockDecoration2
            screenRow: 4
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration3), {
            decoration: blockDecoration3
            screenRow: 5
            isVisible: false
          }
          expectValues stateForBlockDecoration(presenter, blockDecoration4), {
            decoration: blockDecoration4
            screenRow: 10
            isVisible: true
          }

          presenter.invalidateBlockDecorationDimensions(blockDecoration1)
          presenter.setBlockDecorationDimensions(blockDecoration2, 0, 10)
          presenter.setBlockDecorationDimensions(blockDecoration3, 0, 10)

          expectValues stateForBlockDecoration(presenter, blockDecoration1), {
            decoration: blockDecoration1
            screenRow: 0
            isVisible: false
          }
          expect(stateForBlockDecoration(presenter, blockDecoration2)).toBeUndefined()
          expect(stateForBlockDecoration(presenter, blockDecoration3)).toBeUndefined()
          expectValues stateForBlockDecoration(presenter, blockDecoration4), {
            decoration: blockDecoration4
            screenRow: 10
            isVisible: true
          }

          blockDecoration1.destroy()

          expect(stateForBlockDecoration(presenter, blockDecoration1)).toBeUndefined()
          expect(stateForBlockDecoration(presenter, blockDecoration2)).toBeUndefined()
          expect(stateForBlockDecoration(presenter, blockDecoration3)).toBeUndefined()
          expectValues stateForBlockDecoration(presenter, blockDecoration4), {
            decoration: blockDecoration4
            screenRow: 10
            isVisible: true
          }

        it "doesn't throw an error when setting the dimensions for a destroyed decoration", ->
          blockDecoration = addBlockDecorationBeforeScreenRow(0)
          presenter = buildPresenter()

          blockDecoration.destroy()
          presenter.setBlockDecorationDimensions(blockDecoration, 30, 30)

          expect(getState(presenter).content.blockDecorations).toEqual({})

      describe ".overlays", ->
        [item] = []
        stateForOverlay = (presenter, decoration) ->
          getState(presenter).content.overlays[decoration.id]

        it "contains state for overlay decorations both initially and when their markers move", ->
          marker = editor.addMarkerLayer(maintainHistory: true).markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          # Initial state
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
          }

          # Change range
          waitsForStateToUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]])
          runs ->
            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 5 * 10 - presenter.state.content.scrollTop, left: 6 * 10}
            }

            # Valid -> invalid
          waitsForStateToUpdate presenter, -> editor.getBuffer().insert([2, 14], 'x')
          runs ->
            expect(stateForOverlay(presenter, decoration)).toBeUndefined()

            # Invalid -> valid
          waitsForStateToUpdate presenter, -> editor.undo()
          runs ->
            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 5 * 10 - presenter.state.content.scrollTop, left: 6 * 10}
            }

          # Reverse direction
          waitsForStateToUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]], reversed: true)
          runs ->
            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
            }

          # Destroy
          waitsForStateToUpdate presenter, -> decoration.destroy()
          runs ->
            expect(stateForOverlay(presenter, decoration)).toBeUndefined()

          # Add
          decoration2 = null
          waitsForStateToUpdate presenter, -> decoration2 = editor.decorateMarker(marker, {type: 'overlay', item})
          runs ->
            expectValues stateForOverlay(presenter, decoration2), {
              item: item
              pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
            }

        it "updates when character widths changes", ->
          scrollTop = 20
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = buildPresenter({explicitHeight: 30, scrollTop})

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - scrollTop, left: 13 * 10}
          }

          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(5)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - scrollTop, left: 13 * 5}
          }

        it "updates when ::lineHeight changes", ->
          scrollTop = 20
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = buildPresenter({explicitHeight: 30, scrollTop})

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - scrollTop, left: 13 * 10}
          }

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 5 - scrollTop, left: 13 * 10}
          }

        it "honors the 'position' option on overlay decorations", ->
          scrollTop = 20
          marker = editor.markBufferRange([[2, 13], [4, 14]], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', position: 'tail', item})
          presenter = buildPresenter({explicitHeight: 30, scrollTop})
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - scrollTop, left: 13 * 10}
          }

        it "is empty until all of the required measurements are assigned", ->
          marker = editor.markBufferRange([[2, 13], [4, 14]], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', position: 'tail', item})

          presenter = buildPresenterWithoutMeasurements()
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setBaseCharacterWidth(10)
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setLineHeight(10)
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setWindowSize(500, 100)
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setVerticalScrollbarWidth(10)
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setHorizontalScrollbarHeight(10)
          expect(getState(presenter).content.overlays).toEqual({})

          presenter.setBoundingClientRect({top: 0, left: 0, height: 100, width: 500})
          expect(getState(presenter).content.overlays).not.toEqual({})

        describe "when the overlay has been measured", ->
          [gutterWidth, windowWidth, windowHeight, itemWidth, itemHeight, contentMargin, boundingClientRect, contentFrameWidth] = []
          beforeEach ->
            item = {}
            gutterWidth = 5 * 10 # 5 chars wide
            contentFrameWidth = 30 * 10
            windowWidth = gutterWidth + contentFrameWidth
            windowHeight = 9 * 10

            itemWidth = 4 * 10
            itemHeight = 4 * 10
            contentMargin = 0

            boundingClientRect =
              top: 0
              left: 0,
              width: windowWidth
              height: windowHeight

          it "slides horizontally left when near the right edge", ->
            scrollLeft = 20
            marker = editor.markBufferPosition([0, 26], invalidate: 'never')
            decoration = editor.decorateMarker(marker, {type: 'overlay', item})

            presenter = buildPresenter({scrollLeft, windowWidth, windowHeight, contentFrameWidth, boundingClientRect, gutterWidth})
            expectStateUpdate presenter, ->
              presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 1 * 10, left: 26 * 10 + gutterWidth - scrollLeft}
            }

            expectStateUpdate presenter, -> editor.insertText('a')
            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 1 * 10, left: windowWidth - itemWidth}
            }

            expectStateUpdate presenter, -> editor.insertText('b')
            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 1 * 10, left: windowWidth - itemWidth}
            }

          it "flips vertically when near the bottom edge", ->
            scrollTop = 10
            marker = editor.markBufferPosition([5, 0], invalidate: 'never')
            decoration = editor.decorateMarker(marker, {type: 'overlay', item})

            presenter = buildPresenter({scrollTop, windowWidth, windowHeight, contentFrameWidth, boundingClientRect, gutterWidth})
            expectStateUpdate presenter, ->
              presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 6 * 10 - scrollTop, left: gutterWidth}
            }

            expectStateUpdate presenter, ->
              editor.insertNewline()
              presenter.setScrollTop(scrollTop) # I'm fighting the editor

            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 6 * 10 - scrollTop - itemHeight, left: gutterWidth}
            }

          describe "when the overlay item has a margin", ->
            beforeEach ->
              itemWidth = 12 * 10
              contentMargin = -(gutterWidth + 2 * 10)

            it "slides horizontally right when near the left edge with margin", ->
              editor.setCursorBufferPosition([0, 3])
              cursor = editor.getLastCursor()
              marker = cursor.marker
              decoration = editor.decorateMarker(marker, {type: 'overlay', item})

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect, gutterWidth})
              expectStateUpdate presenter, ->
                presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 1 * 10, left: 3 * 10 + gutterWidth}
              }

              expectStateUpdate presenter, -> cursor.moveLeft()
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 1 * 10, left: -contentMargin}
              }

              expectStateUpdate presenter, -> cursor.moveLeft()
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 1 * 10, left: -contentMargin}
              }

          describe "when the editor is very small", ->
            beforeEach ->
              windowWidth = gutterWidth + 6 * 10
              windowHeight = 6 * 10
              contentFrameWidth = windowWidth - gutterWidth
              boundingClientRect.width = windowWidth
              boundingClientRect.height = windowHeight

            it "does not flip vertically and force the overlay to have a negative top", ->
              marker = editor.markBufferPosition([1, 0], invalidate: 'never')
              decoration = editor.decorateMarker(marker, {type: 'overlay', item})

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect, gutterWidth})
              expectStateUpdate presenter, ->
                presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 2 * 10, left: 0 * 10 + gutterWidth}
              }

              expectStateUpdate presenter, -> editor.insertNewline()
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 3 * 10, left: gutterWidth}
              }

            it "does not adjust horizontally and force the overlay to have a negative left", ->
              itemWidth = 6 * 10

              marker = editor.markBufferPosition([0, 0], invalidate: 'never')
              decoration = editor.decorateMarker(marker, {type: 'overlay', item})

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect, gutterWidth})
              expectStateUpdate presenter, ->
                presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 10, left: gutterWidth}
              }

              windowWidth = gutterWidth + 5 * 10
              expectStateUpdate presenter, -> presenter.setWindowSize(windowWidth, windowHeight)
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 10, left: windowWidth - itemWidth}
              }

              windowWidth = gutterWidth + 1 * 10
              expectStateUpdate presenter, -> presenter.setWindowSize(windowWidth, windowHeight)
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 10, left: 0}
              }

              windowWidth = gutterWidth
              expectStateUpdate presenter, -> presenter.setWindowSize(windowWidth, windowHeight)
              expectValues stateForOverlay(presenter, decoration), {
                item: item
                pixelPosition: {top: 10, left: 0}
              }

    describe ".height", ->
      it "updates model's rows per page when it changes", ->
        presenter = buildPresenter(explicitHeight: 50, lineHeightInPixels: 10, horizontalScrollbarHeight: 10)

        getState(presenter) # trigger state update
        expect(editor.getRowsPerPage()).toBe(4)

        presenter.setExplicitHeight(100)
        getState(presenter) # trigger state update
        expect(editor.getRowsPerPage()).toBe(9)

        presenter.setHorizontalScrollbarHeight(0)
        getState(presenter) # trigger state update
        expect(editor.getRowsPerPage()).toBe(10)

        presenter.setLineHeight(5)
        getState(presenter) # trigger state update
        expect(editor.getRowsPerPage()).toBe(20)

      it "tracks the computed content height if ::autoHeight is true so the editor auto-expands vertically", ->
        presenter = buildPresenter(explicitHeight: null)
        presenter.setAutoHeight(true)
        expect(getState(presenter).height).toBe editor.getScreenLineCount() * 10

        expectStateUpdate presenter, -> presenter.setAutoHeight(false)
        expect(getState(presenter).height).toBe null

        expectStateUpdate presenter, -> presenter.setAutoHeight(true)
        expect(getState(presenter).height).toBe editor.getScreenLineCount() * 10

        expectStateUpdate presenter, -> presenter.setLineHeight(20)
        expect(getState(presenter).height).toBe editor.getScreenLineCount() * 20

        expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
        expect(getState(presenter).height).toBe editor.getScreenLineCount() * 20

    describe ".focused", ->
      it "tracks the value of ::focused", ->
        presenter = buildPresenter()
        presenter.setFocused(false)

        expect(getState(presenter).focused).toBe false
        expectStateUpdate presenter, -> presenter.setFocused(true)
        expect(getState(presenter).focused).toBe true
        expectStateUpdate presenter, -> presenter.setFocused(false)
        expect(getState(presenter).focused).toBe false

    describe ".gutters", ->
      getStateForGutterWithName = (presenter, gutterName) ->
        gutterDescriptions = getState(presenter).gutters
        for description in gutterDescriptions
          gutter = description.gutter
          return description if gutter.name is gutterName

      describe "the array itself, an array of gutter descriptions", ->
        it "updates when gutters are added to the editor model, and keeps the gutters sorted by priority", ->
          presenter = buildPresenter()
          gutter1 = editor.addGutter({name: 'test-gutter-1', priority: -100, visible: true})
          gutter2 = editor.addGutter({name: 'test-gutter-2', priority: 100, visible: false})

          expectedGutterOrder = [gutter1, editor.gutterWithName('line-number'), gutter2]
          for gutterDescription, index in getState(presenter).gutters
            expect(gutterDescription.gutter).toEqual expectedGutterOrder[index]

        it "updates when the visibility of a gutter changes", ->
          presenter = buildPresenter()
          gutter = editor.addGutter({name: 'test-gutter', visible: true})
          expect(getStateForGutterWithName(presenter, 'test-gutter').visible).toBe true
          gutter.hide()
          expect(getStateForGutterWithName(presenter, 'test-gutter').visible).toBe false

        it "updates when a gutter is removed", ->
          presenter = buildPresenter()
          gutter = editor.addGutter({name: 'test-gutter', visible: true})
          expect(getStateForGutterWithName(presenter, 'test-gutter').visible).toBe true
          gutter.destroy()
          expect(getStateForGutterWithName(presenter, 'test-gutter')).toBeUndefined()

      describe "for a gutter description that corresponds to the line-number gutter", ->
        getLineNumberGutterState = (presenter) ->
          gutterDescriptions = getState(presenter).gutters
          for description in gutterDescriptions
            gutter = description.gutter
            return description if gutter.name is 'line-number'

        describe ".visible", ->
          it "is true iff the editor isn't mini, ::isLineNumberGutterVisible is true on the editor, and the 'editor.showLineNumbers' config is enabled", ->
            presenter = buildPresenter()

            expect(editor.isLineNumberGutterVisible()).toBe true
            expect(getLineNumberGutterState(presenter).visible).toBe true

            expectStateUpdate presenter, -> editor.setMini(true)
            expect(getLineNumberGutterState(presenter)).toBeUndefined()

            expectStateUpdate presenter, -> editor.setMini(false)
            expect(getLineNumberGutterState(presenter).visible).toBe true

            expectStateUpdate presenter, -> editor.setLineNumberGutterVisible(false)
            expect(getLineNumberGutterState(presenter).visible).toBe false

            expectStateUpdate presenter, -> editor.setLineNumberGutterVisible(true)
            expect(getLineNumberGutterState(presenter).visible).toBe true

            expectStateUpdate presenter, -> atom.config.set('editor.showLineNumbers', false)
            expect(getLineNumberGutterState(presenter).visible).toBe false

          it "gets updated when the editor's grammar changes", ->
            presenter = buildPresenter()

            atom.config.set('editor.showLineNumbers', false, scopeSelector: '.source.js')
            expect(getLineNumberGutterState(presenter).visible).toBe true
            stateUpdated = false
            presenter.onDidUpdateState -> stateUpdated = true

            waitsForPromise -> atom.packages.activatePackage('language-javascript')

            runs ->
              expect(stateUpdated).toBe true
              expect(getLineNumberGutterState(presenter).visible).toBe false

        describe ".content.maxLineNumberDigits", ->
          it "is set to the number of digits used by the greatest line number", ->
            presenter = buildPresenter()
            expect(editor.getLastBufferRow()).toBe 12
            expect(getLineNumberGutterState(presenter).content.maxLineNumberDigits).toBe 2

            editor.setText("1\n2\n3")
            expect(getLineNumberGutterState(presenter).content.maxLineNumberDigits).toBe 1

        describe ".content.tiles", ->
          lineNumberStateForScreenRow = (presenter, screenRow) ->
            tilesState = getLineNumberGutterState(presenter).content.tiles
            line = presenter.linesByScreenRow.get(screenRow)
            tilesState[presenter.tileForRow(screenRow)]?.lineNumbers[line?.id]

          tiledContentContract (presenter) -> getLineNumberGutterState(presenter).content

          describe ".lineNumbers[id]", ->
            it "contains states for line numbers that are visible on screen", ->
              editor.foldBufferRow(4)
              editor.setSoftWrapped(true)
              editor.setDefaultCharWidth(1)
              editor.setEditorWidthInChars(51)
              presenter = buildPresenter(explicitHeight: 25, scrollTop: 30, lineHeight: 10, tileSize: 3)
              presenter.setScreenRowsToMeasure([9, 11])

              expect(lineNumberStateForScreenRow(presenter, 2)).toBeUndefined()
              expectValues lineNumberStateForScreenRow(presenter, 3), {screenRow: 3, bufferRow: 3, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 4), {screenRow: 4, bufferRow: 3, softWrapped: true}
              expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 4, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 7, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 8, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 8), {screenRow: 8, bufferRow: 8, softWrapped: true}
              expect(lineNumberStateForScreenRow(presenter, 9)).toBeUndefined()
              expect(lineNumberStateForScreenRow(presenter, 10)).toBeUndefined()
              expect(lineNumberStateForScreenRow(presenter, 11)).toBeUndefined()
              expect(lineNumberStateForScreenRow(presenter, 12)).toBeUndefined()

            it "updates when the editor's content changes", ->
              editor.foldBufferRow(4)
              editor.setSoftWrapped(true)
              editor.setDefaultCharWidth(1)
              editor.setEditorWidthInChars(50)
              presenter = buildPresenter(explicitHeight: 35, scrollTop: 30, tileSize: 2)

              expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
              expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
              expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
              expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
              expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 4}
              expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 7}
              expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
              expectValues lineNumberStateForScreenRow(presenter, 8), {bufferRow: 8}
              expectValues lineNumberStateForScreenRow(presenter, 9), {bufferRow: 9}
              expect(lineNumberStateForScreenRow(presenter, 10)).toBeUndefined()

              expectStateUpdate presenter, ->
                editor.getBuffer().insert([3, Infinity], new Array(25).join("x "))

              expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
              expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
              expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
              expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
              expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 3}
              expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 4}
              expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 7}
              expectValues lineNumberStateForScreenRow(presenter, 8), {bufferRow: 8}
              expectValues lineNumberStateForScreenRow(presenter, 9), {bufferRow: 8}
              expect(lineNumberStateForScreenRow(presenter, 10)).toBeUndefined()

            it "correctly handles the first screen line being soft-wrapped", ->
              editor.setSoftWrapped(true)
              editor.setDefaultCharWidth(1)
              editor.setEditorWidthInChars(30)
              presenter = buildPresenter(explicitHeight: 25, scrollTop: 50, tileSize: 2)

              expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 3, softWrapped: true}
              expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 3, softWrapped: true}
              expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 4, softWrapped: false}

              presenter.setContentFrameWidth(500)

              expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 4, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 5, softWrapped: false}
              expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 6, softWrapped: false}

          describe ".blockDecorationsHeight", ->
            it "adds the sum of all block decorations' heights to the relevant line number state objects, both initially and when decorations change", ->
              blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
              presenter = buildPresenter(tileSize: 2, explicitHeight: 300)
              blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
              blockDecoration3 = addBlockDecorationBeforeScreenRow(3)
              blockDecoration4 = addBlockDecorationBeforeScreenRow(7)
              blockDecoration5 = addBlockDecorationAfterScreenRow(7)
              blockDecoration6 = addBlockDecorationAfterScreenRow(10)

              presenter.setBlockDecorationDimensions(blockDecoration1, 0, 10)
              presenter.setBlockDecorationDimensions(blockDecoration2, 0, 20)
              presenter.setBlockDecorationDimensions(blockDecoration3, 0, 30)
              presenter.setBlockDecorationDimensions(blockDecoration4, 0, 35)
              presenter.setBlockDecorationDimensions(blockDecoration4, 0, 40)
              presenter.setBlockDecorationDimensions(blockDecoration5, 0, 50)

              waitsForStateToUpdate presenter, -> presenter.setBlockDecorationDimensions(blockDecoration6, 0, 60)
              runs ->
                expect(lineNumberStateForScreenRow(presenter, 0).blockDecorationsHeight).toBe(10)
                expect(lineNumberStateForScreenRow(presenter, 1).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 2).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 3).blockDecorationsHeight).toBe(20 + 30)
                expect(lineNumberStateForScreenRow(presenter, 4).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 5).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 6).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 7).blockDecorationsHeight).toBe(40)
                expect(lineNumberStateForScreenRow(presenter, 8).blockDecorationsHeight).toBe(0) # 0 because we're at the start of a tile.
                expect(lineNumberStateForScreenRow(presenter, 9).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 10).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 11).blockDecorationsHeight).toBe(60)

              waitsForStateToUpdate presenter, ->
                blockDecoration1.getMarker().setHeadBufferPosition([1, 0])
                blockDecoration2.getMarker().setHeadBufferPosition([5, 0])
                blockDecoration3.getMarker().setHeadBufferPosition([9, 0])

              runs ->
                expect(lineNumberStateForScreenRow(presenter, 0).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 1).blockDecorationsHeight).toBe(10)
                expect(lineNumberStateForScreenRow(presenter, 2).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 3).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 4).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 5).blockDecorationsHeight).toBe(20)
                expect(lineNumberStateForScreenRow(presenter, 6).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 7).blockDecorationsHeight).toBe(40)
                expect(lineNumberStateForScreenRow(presenter, 8).blockDecorationsHeight).toBe(0) # 0 because we're at the start of a tile.
                expect(lineNumberStateForScreenRow(presenter, 9).blockDecorationsHeight).toBe(30)
                expect(lineNumberStateForScreenRow(presenter, 10).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 11).blockDecorationsHeight).toBe(60)

              waitsForStateToUpdate presenter, ->
                blockDecoration1.destroy()
                blockDecoration3.destroy()

              runs ->
                expect(lineNumberStateForScreenRow(presenter, 0).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 1).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 2).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 3).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 4).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 5).blockDecorationsHeight).toBe(20)
                expect(lineNumberStateForScreenRow(presenter, 6).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 7).blockDecorationsHeight).toBe(40)
                expect(lineNumberStateForScreenRow(presenter, 8).blockDecorationsHeight).toBe(0) # 0 because we're at the start of a tile.
                expect(lineNumberStateForScreenRow(presenter, 9).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 10).blockDecorationsHeight).toBe(0)
                expect(lineNumberStateForScreenRow(presenter, 11).blockDecorationsHeight).toBe(60)

            describe ".decorationClasses", ->
              it "adds decoration classes to the relevant line number state objects, both initially and when decorations change", ->
                marker1 = editor.addMarkerLayer(maintainHistory: true).markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
                decoration1 = editor.decorateMarker(marker1, type: 'line-number', class: 'a')
                marker2 = editor.addMarkerLayer(maintainHistory: true).markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
                decoration2 = editor.decorateMarker(marker2, type: 'line-number', class: 'b')
                presenter = buildPresenter()

                expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
                expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
                expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
                runs ->
                  expect(marker1.isValid()).toBe false
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> editor.undo()
                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
                  expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
                  expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
                  expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> decoration1.destroy()
                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
                  expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> marker2.destroy()
                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              it "honors the 'onlyEmpty' option on line-number decorations", ->
                marker = editor.markBufferRange([[4, 0], [6, 1]])
                decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyEmpty: true)
                presenter = buildPresenter()

                expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> marker.clearTail()

                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

              it "honors the 'onlyNonEmpty' option on line-number decorations", ->
                marker = editor.markBufferRange([[4, 0], [6, 2]])
                decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyNonEmpty: true)
                presenter = buildPresenter()

                expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
                expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
                expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

                waitsForStateToUpdate presenter, -> marker.clearTail()

                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              it "honors the 'onlyHead' option on line-number decorations", ->
                marker = editor.markBufferRange([[4, 0], [6, 2]])
                decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyHead: true)
                presenter = buildPresenter()

                expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
                expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
                expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

              it "does not decorate the last line of a non-empty line-number decoration range if it ends at column 0", ->
                marker = editor.markBufferRange([[4, 0], [6, 0]])
                decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')
                presenter = buildPresenter()

                expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
                expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
                expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              it "does not apply line-number decorations to mini editors", ->
                editor.setMini(true)
                presenter = buildPresenter()
                marker = editor.markBufferRange([[0, 0], [0, 0]])
                decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')
                # A mini editor will have no gutters.
                expect(getLineNumberGutterState(presenter)).toBeUndefined()

                expectStateUpdate presenter, -> editor.setMini(false)
                expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'cursor-line-no-selection', 'a']

                expectStateUpdate presenter, -> editor.setMini(true)
                expect(getLineNumberGutterState(presenter)).toBeUndefined()

              it "only applies line-number decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
                editor.setText("a line that wraps, ok")
                editor.setSoftWrapped(true)
                editor.setDefaultCharWidth(1)
                editor.setEditorWidthInChars(16)
                marker = editor.markBufferRange([[0, 0], [0, 2]])
                editor.decorateMarker(marker, type: 'line-number', class: 'a')
                presenter = buildPresenter(explicitHeight: 10)

                expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
                expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

                waitsForStateToUpdate presenter, -> marker.setBufferRange([[0, 0], [0, Infinity]])
                runs ->
                  expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
                  expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

              describe "when a fold spans a single soft-wrapped buffer row", ->
                it "applies the 'folded' decoration only to its initial screen row", ->
                  editor.setSoftWrapped(true)
                  editor.setDefaultCharWidth(1)
                  editor.setEditorWidthInChars(20)
                  editor.foldBufferRange([[0, 20], [0, 22]])
                  editor.foldBufferRange([[0, 10], [0, 14]])
                  presenter = buildPresenter(explicitHeight: 35, scrollTop: 0, tileSize: 2)

                  expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain('folded')
                  expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

              describe "when a fold is at the end of a soft-wrapped buffer row", ->
                it "applies the 'folded' decoration only to its initial screen row", ->
                  editor.setSoftWrapped(true)
                  editor.setDefaultCharWidth(1)
                  editor.setEditorWidthInChars(25)
                  editor.foldBufferRow(1)
                  presenter = buildPresenter(explicitHeight: 35, scrollTop: 0, tileSize: 2)

                  expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toContain('folded')
                  expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()

            describe ".foldable", ->
              it "marks line numbers at the start of a foldable region as foldable", ->
                presenter = buildPresenter()
                expect(lineNumberStateForScreenRow(presenter, 0).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 1).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 2).foldable).toBe false
                expect(lineNumberStateForScreenRow(presenter, 3).foldable).toBe false
                expect(lineNumberStateForScreenRow(presenter, 4).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 5).foldable).toBe false

              it "updates the foldable class on the correct line numbers when the foldable positions change", ->
                presenter = buildPresenter()
                editor.getBuffer().insert([0, 0], '\n')
                expect(lineNumberStateForScreenRow(presenter, 0).foldable).toBe false
                expect(lineNumberStateForScreenRow(presenter, 1).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 2).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 3).foldable).toBe false
                expect(lineNumberStateForScreenRow(presenter, 4).foldable).toBe false
                expect(lineNumberStateForScreenRow(presenter, 5).foldable).toBe true
                expect(lineNumberStateForScreenRow(presenter, 6).foldable).toBe false

              it "updates the foldable class on a line number that becomes foldable", ->
                presenter = buildPresenter()
                expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe false

                editor.getBuffer().insert([11, 44], '\n    fold me')
                expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe true

                editor.undo()
                expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe false

      describe "for a gutter description that corresponds to a custom gutter", ->
        describe ".content", ->
          getContentForGutterWithName = (presenter, gutterName) ->
            fullState = getStateForGutterWithName(presenter, gutterName)
            return fullState.content if fullState

          [presenter, gutter, decorationItem, decorationParams] = []
          [marker1, decoration1, marker2, decoration2, marker3, decoration3] = []

          # Set the scrollTop to 0 to show the very top of the file.
          # Set the explicitHeight to make 10 lines visible.
          scrollTop = 0
          lineHeight = 10
          explicitHeight = lineHeight * 10

          beforeEach ->
            # At the beginning of each test, decoration1 and decoration2 are in visible range,
            # but not decoration3.
            presenter = buildPresenter({explicitHeight, scrollTop, lineHeight})
            gutter = editor.addGutter({name: 'test-gutter', visible: true})
            decorationItem = document.createElement('div')
            decorationItem.class = 'decoration-item'
            decorationParams =
              type: 'gutter'
              gutterName: 'test-gutter'
              class: 'test-class'
              item: decorationItem
            marker1 = editor.markBufferRange([[0, 0], [1, 0]])
            decoration1 = editor.decorateMarker(marker1, decorationParams)
            marker2 = editor.markBufferRange([[9, 0], [12, 0]])
            decoration2 = editor.decorateMarker(marker2, decorationParams)
            marker3 = editor.markBufferRange([[13, 0], [14, 0]])
            decoration3 = editor.decorateMarker(marker3, decorationParams)

            # Clear any batched state updates.
            getState(presenter)

          it "contains all decorations within the visible buffer range", ->
            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBe lineHeight * marker1.getScreenRange().start.row
            expect(decorationState[decoration1.id].height).toBe lineHeight * marker1.getScreenRange().getRowCount()
            expect(decorationState[decoration1.id].item).toBe decorationItem
            expect(decorationState[decoration1.id].class).toBe 'test-class'

            expect(decorationState[decoration2.id].top).toBe lineHeight * marker2.getScreenRange().start.row
            expect(decorationState[decoration2.id].height).toBe lineHeight * marker2.getScreenRange().getRowCount()
            expect(decorationState[decoration2.id].item).toBe decorationItem
            expect(decorationState[decoration2.id].class).toBe 'test-class'

            expect(decorationState[decoration3.id]).toBeUndefined()

          it "updates all the gutters, even when a gutter with higher priority is hidden", ->
            hiddenGutter = {name: 'test-gutter-1', priority: -150, visible: false}
            editor.addGutter(hiddenGutter)

            # This update will scroll decoration1 out of view, and decoration3 into view.
            expectStateUpdate presenter, -> presenter.setScrollTop(scrollTop + lineHeight * 5)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id]).toBeUndefined()
            expect(decorationState[decoration3.id].top).toBeDefined()

          it "updates when block decorations are added, changed or removed", ->
            # block decoration before decoration1
            blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
            presenter.setBlockDecorationDimensions(blockDecoration1, 0, 3)
            # block decoration between decoration1 and decoration2
            blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
            presenter.setBlockDecorationDimensions(blockDecoration2, 0, 5)
            # block decoration between decoration2 and decoration3
            blockDecoration3 = addBlockDecorationBeforeScreenRow(10)
            blockDecoration4 = addBlockDecorationAfterScreenRow(10)
            presenter.setBlockDecorationDimensions(blockDecoration3, 0, 7)
            presenter.setBlockDecorationDimensions(blockDecoration4, 0, 11)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBe lineHeight * marker1.getScreenRange().start.row + 3
            expect(decorationState[decoration1.id].height).toBe lineHeight * marker1.getScreenRange().getRowCount()
            expect(decorationState[decoration1.id].item).toBe decorationItem
            expect(decorationState[decoration1.id].class).toBe 'test-class'
            expect(decorationState[decoration2.id].top).toBe lineHeight * marker2.getScreenRange().start.row + 3 + 5
            expect(decorationState[decoration2.id].height).toBe lineHeight * marker2.getScreenRange().getRowCount() + 7 + 11
            expect(decorationState[decoration2.id].item).toBe decorationItem
            expect(decorationState[decoration2.id].class).toBe 'test-class'
            expect(decorationState[decoration3.id]).toBeUndefined()

            presenter.setScrollTop(scrollTop + lineHeight * 5)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id]).toBeUndefined()
            expect(decorationState[decoration2.id].top).toBe lineHeight * marker2.getScreenRange().start.row + 3 + 5
            expect(decorationState[decoration2.id].height).toBe lineHeight * marker2.getScreenRange().getRowCount() + 7 + 11
            expect(decorationState[decoration2.id].item).toBe decorationItem
            expect(decorationState[decoration2.id].class).toBe 'test-class'
            expect(decorationState[decoration3.id].top).toBe lineHeight * marker3.getScreenRange().start.row + 3 + 5 + 7 + 11
            expect(decorationState[decoration3.id].height).toBe lineHeight * marker3.getScreenRange().getRowCount()
            expect(decorationState[decoration3.id].item).toBe decorationItem
            expect(decorationState[decoration3.id].class).toBe 'test-class'

            waitsForStateToUpdate presenter, -> blockDecoration1.destroy()
            runs ->
              decorationState = getContentForGutterWithName(presenter, 'test-gutter')
              expect(decorationState[decoration1.id]).toBeUndefined()
              expect(decorationState[decoration2.id].top).toBe lineHeight * marker2.getScreenRange().start.row + 5
              expect(decorationState[decoration2.id].height).toBe lineHeight * marker2.getScreenRange().getRowCount() + 7 + 11
              expect(decorationState[decoration2.id].item).toBe decorationItem
              expect(decorationState[decoration2.id].class).toBe 'test-class'
              expect(decorationState[decoration3.id].top).toBe lineHeight * marker3.getScreenRange().start.row + 5 + 7 + 11
              expect(decorationState[decoration3.id].height).toBe lineHeight * marker3.getScreenRange().getRowCount()
              expect(decorationState[decoration3.id].item).toBe decorationItem
              expect(decorationState[decoration3.id].class).toBe 'test-class'

          it "updates when ::scrollTop changes", ->
            # This update will scroll decoration1 out of view, and decoration3 into view.
            expectStateUpdate presenter, -> presenter.setScrollTop(scrollTop + lineHeight * 5)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id]).toBeUndefined()
            expect(decorationState[decoration2.id].top).toBeDefined()
            expect(decorationState[decoration3.id].top).toBeDefined()

          it "updates when ::explicitHeight changes", ->
            # This update will make all three decorations visible.
            expectStateUpdate presenter, -> presenter.setExplicitHeight(explicitHeight + lineHeight * 5)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBeDefined()
            expect(decorationState[decoration2.id].top).toBeDefined()
            expect(decorationState[decoration3.id].top).toBeDefined()

          it "updates when ::lineHeight changes", ->
            # This update will make all three decorations visible.
            expectStateUpdate presenter, -> presenter.setLineHeight(Math.ceil(1.0 * explicitHeight / marker3.getBufferRange().end.row))

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')

            expect(decorationState[decoration1.id].top).toBeDefined()
            expect(decorationState[decoration2.id].top).toBeDefined()
            expect(decorationState[decoration3.id].top).toBeDefined()

          it "updates when the editor's content changes", ->
            # This update will add enough lines to push decoration2 out of view.
            expectStateUpdate presenter, -> editor.setTextInBufferRange([[8, 0], [9, 0]], '\n\n\n\n\n')

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBeDefined()
            expect(decorationState[decoration2.id]).toBeUndefined()
            expect(decorationState[decoration3.id]).toBeUndefined()

          it "updates when a decoration's marker is modified", ->
            # This update will move decoration1 out of view.
            waitsForStateToUpdate presenter, ->
              newRange = new Range([13, 0], [14, 0])
              marker1.setBufferRange(newRange)

            runs ->
              decorationState = getContentForGutterWithName(presenter, 'test-gutter')
              expect(decorationState[decoration1.id]).toBeUndefined()
              expect(decorationState[decoration2.id].top).toBeDefined()
              expect(decorationState[decoration3.id]).toBeUndefined()

          describe "when a decoration's properties are modified", ->
            it "updates the item applied to the decoration, if the decoration item is changed", ->
              # This changes the decoration class. The visibility of the decoration should not be affected.
              newItem = document.createElement('div')
              newItem.class = 'new-decoration-item'
              newDecorationParams =
                type: 'gutter'
                gutterName: 'test-gutter'
                class: 'test-class'
                item: newItem

              waitsForStateToUpdate presenter, -> decoration1.setProperties(newDecorationParams)

              runs ->
                decorationState = getContentForGutterWithName(presenter, 'test-gutter')
                expect(decorationState[decoration1.id].item).toBe newItem
                expect(decorationState[decoration2.id].item).toBe decorationItem
                expect(decorationState[decoration3.id]).toBeUndefined()

            it "updates the class applied to the decoration, if the decoration class is changed", ->
              # This changes the decoration item. The visibility of the decoration should not be affected.
              newDecorationParams =
                type: 'gutter'
                gutterName: 'test-gutter'
                class: 'new-test-class'
                item: decorationItem
              waitsForStateToUpdate presenter, -> decoration1.setProperties(newDecorationParams)

              runs ->
                decorationState = getContentForGutterWithName(presenter, 'test-gutter')
                expect(decorationState[decoration1.id].class).toBe 'new-test-class'
                expect(decorationState[decoration2.id].class).toBe 'test-class'
                expect(decorationState[decoration3.id]).toBeUndefined()

            it "updates the type of the decoration, if the decoration type is changed", ->
              # This changes the type of the decoration. This should remove the decoration from the gutter.
              newDecorationParams =
                type: 'line'
                gutterName: 'test-gutter' # This is an invalid/meaningless option here, but it shouldn't matter.
                class: 'test-class'
                item: decorationItem
              waitsForStateToUpdate presenter, -> decoration1.setProperties(newDecorationParams)

              runs ->
                decorationState = getContentForGutterWithName(presenter, 'test-gutter')
                expect(decorationState[decoration1.id]).toBeUndefined()
                expect(decorationState[decoration2.id].top).toBeDefined()
                expect(decorationState[decoration3.id]).toBeUndefined()

            it "updates the gutter the decoration targets, if the decoration gutterName is changed", ->
              # This changes which gutter this decoration applies to. Since this gutter does not exist,
              # the decoration should not appear in the customDecorations state.
              newDecorationParams =
                type: 'gutter'
                gutterName: 'test-gutter-2'
                class: 'new-test-class'
                item: decorationItem
              waitsForStateToUpdate presenter, -> decoration1.setProperties(newDecorationParams)

              runs ->
                decorationState = getContentForGutterWithName(presenter, 'test-gutter')
                expect(decorationState[decoration1.id]).toBeUndefined()
                expect(decorationState[decoration2.id].top).toBeDefined()
                expect(decorationState[decoration3.id]).toBeUndefined()

                # After adding the targeted gutter, the decoration will appear in the state for that gutter,
                # since it should be visible.
                expectStateUpdate presenter, -> editor.addGutter({name: 'test-gutter-2'})
                newGutterDecorationState = getContentForGutterWithName(presenter, 'test-gutter-2')
                expect(newGutterDecorationState[decoration1.id].top).toBeDefined()
                expect(newGutterDecorationState[decoration2.id]).toBeUndefined()
                expect(newGutterDecorationState[decoration3.id]).toBeUndefined()
                oldGutterDecorationState = getContentForGutterWithName(presenter, 'test-gutter')
                expect(oldGutterDecorationState[decoration1.id]).toBeUndefined()
                expect(oldGutterDecorationState[decoration2.id].top).toBeDefined()
                expect(oldGutterDecorationState[decoration3.id]).toBeUndefined()

          it "updates when the editor's mini state changes, and is cleared when the editor is mini", ->
            expectStateUpdate presenter, -> editor.setMini(true)
            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState).toBeUndefined()

            # The decorations should return to the original state.
            expectStateUpdate presenter, -> editor.setMini(false)
            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBeDefined()
            expect(decorationState[decoration2.id].top).toBeDefined()
            expect(decorationState[decoration3.id]).toBeUndefined()

          it "updates when a gutter's visibility changes, and is cleared when the gutter is not visible", ->
            expectStateUpdate presenter, -> gutter.hide()
            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id]).toBeUndefined()
            expect(decorationState[decoration2.id]).toBeUndefined()
            expect(decorationState[decoration3.id]).toBeUndefined()

            # The decorations should return to the original state.
            expectStateUpdate presenter, -> gutter.show()
            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBeDefined()
            expect(decorationState[decoration2.id].top).toBeDefined()
            expect(decorationState[decoration3.id]).toBeUndefined()

          it "updates when a gutter is added to the editor", ->
            decorationParams =
              type: 'gutter'
              gutterName: 'test-gutter-2'
              class: 'test-class'
            marker4 = editor.markBufferRange([[0, 0], [1, 0]])
            decoration4 = null

            waitsForStateToUpdate presenter, -> decoration4 = editor.decorateMarker(marker4, decorationParams)

            runs ->
              expectStateUpdate presenter, -> editor.addGutter({name: 'test-gutter-2'})

              decorationState = getContentForGutterWithName(presenter, 'test-gutter-2')
              expect(decorationState[decoration1.id]).toBeUndefined()
              expect(decorationState[decoration2.id]).toBeUndefined()
              expect(decorationState[decoration3.id]).toBeUndefined()
              expect(decorationState[decoration4.id].top).toBeDefined()

          it "updates when editor lines are folded", ->
            oldDimensionsForDecoration1 =
              top: lineHeight * marker1.getScreenRange().start.row
              height: lineHeight * marker1.getScreenRange().getRowCount()
            oldDimensionsForDecoration2 =
              top: lineHeight * marker2.getScreenRange().start.row
              height: lineHeight * marker2.getScreenRange().getRowCount()

            # Based on the contents of sample.js, this should affect all but the top
            # part of decoration1.
            expectStateUpdate presenter, -> editor.foldBufferRow(0)

            decorationState = getContentForGutterWithName(presenter, 'test-gutter')
            expect(decorationState[decoration1.id].top).toBe oldDimensionsForDecoration1.top
            expect(decorationState[decoration1.id].height).not.toBe oldDimensionsForDecoration1.height
            # Due to the issue described here: https://github.com/atom/atom/issues/6454, decoration2
            # will be bumped up to the row that was folded and still made visible, instead of being
            # entirely collapsed. (The same thing will happen to decoration3.)
            expect(decorationState[decoration2.id].top).not.toBe oldDimensionsForDecoration2.top
            expect(decorationState[decoration2.id].height).not.toBe oldDimensionsForDecoration2.height

      describe "regardless of what kind of gutter a gutter description corresponds to", ->
        [customGutter] = []

        getStylesForGutterWithName = (presenter, gutterName) ->
          fullState = getStateForGutterWithName(presenter, gutterName)
          return fullState.styles if fullState

        beforeEach ->
          customGutter = editor.addGutter({name: 'test-gutter', priority: -1, visible: true})

        afterEach ->
          customGutter.destroy()

        describe ".scrollHeight", ->
          it "updates when new block decorations are measured, changed or destroyed", ->
            presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
            expect(getState(presenter).verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

            blockDecoration1 = addBlockDecorationBeforeScreenRow(0)
            blockDecoration2 = addBlockDecorationBeforeScreenRow(3)
            blockDecoration3 = addBlockDecorationBeforeScreenRow(7)

            presenter.setBlockDecorationDimensions(blockDecoration1, 0, 35.8)
            presenter.setBlockDecorationDimensions(blockDecoration2, 0, 50.3)
            presenter.setBlockDecorationDimensions(blockDecoration3, 0, 95.2)

            linesHeight = editor.getScreenLineCount() * 10
            blockDecorationsHeight = Math.round(35.8 + 50.3 + 95.2)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe(linesHeight + blockDecorationsHeight)

            presenter.setBlockDecorationDimensions(blockDecoration2, 0, 100.3)

            blockDecorationsHeight = Math.round(35.8 + 100.3 + 95.2)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe(linesHeight + blockDecorationsHeight)

            waitsForStateToUpdate presenter, -> blockDecoration3.destroy()
            runs ->
              blockDecorationsHeight = Math.round(35.8 + 100.3)
              expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe(linesHeight + blockDecorationsHeight)

          it "is initialized based on ::lineHeight, the number of lines, and ::explicitHeight", ->
            presenter = buildPresenter()
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe editor.getScreenLineCount() * 10
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe editor.getScreenLineCount() * 10

            presenter = buildPresenter(explicitHeight: 500)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe 500
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe 500

          it "updates when the ::lineHeight changes", ->
            presenter = buildPresenter()
            expectStateUpdate presenter, -> presenter.setLineHeight(20)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe editor.getScreenLineCount() * 20
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe editor.getScreenLineCount() * 20

          it "updates when the line count changes", ->
            presenter = buildPresenter()
            expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe editor.getScreenLineCount() * 10
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe editor.getScreenLineCount() * 10

          it "updates when ::explicitHeight changes", ->
            presenter = buildPresenter()
            expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe 500
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe 500

          it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
            expectStateUpdate presenter, -> presenter.setScrollTop(300)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe presenter.contentHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe presenter.contentHeight

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollHeight).toBe presenter.contentHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollHeight).toBe presenter.contentHeight

        describe ".scrollTop", ->
          it "tracks the value of ::scrollTop", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 20)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe 10
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe 10
            expectStateUpdate presenter, -> presenter.setScrollTop(50)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe 50
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe 50

          it "never exceeds the computed scrollHeight minus the computed clientHeight", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
            expectStateUpdate presenter, -> presenter.setScrollTop(100)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

            expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

            expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

            expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

            # Scroll top only gets smaller when needed as dimensions change, never bigger
            scrollTopBefore = getState(presenter).verticalScrollbar.scrollTop
            expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe scrollTopBefore
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe scrollTopBefore

          it "never goes negative", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
            expectStateUpdate presenter, -> presenter.setScrollTop(-100)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe 0
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe 0

          it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
            presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
            expectStateUpdate presenter, -> presenter.setScrollTop(300)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.contentHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.contentHeight - presenter.clientHeight

            atom.config.set("editor.scrollPastEnd", true)
            expectStateUpdate presenter, -> presenter.setScrollTop(300)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

            expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
            expect(getStylesForGutterWithName(presenter, 'line-number').scrollTop).toBe presenter.contentHeight - presenter.clientHeight
            expect(getStylesForGutterWithName(presenter, 'test-gutter').scrollTop).toBe presenter.contentHeight - presenter.clientHeight

        describe ".backgroundColor", ->
          it "is assigned to ::gutterBackgroundColor if present, and to ::backgroundColor otherwise", ->
            presenter = buildPresenter()
            presenter.setBackgroundColor("rgba(255, 0, 0, 0)")
            presenter.setGutterBackgroundColor("rgba(0, 255, 0, 0)")
            expect(getStylesForGutterWithName(presenter, 'line-number').backgroundColor).toBe "rgba(0, 255, 0, 0)"
            expect(getStylesForGutterWithName(presenter, 'test-gutter').backgroundColor).toBe "rgba(0, 255, 0, 0)"

            expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 255, 0)")
            expect(getStylesForGutterWithName(presenter, 'line-number').backgroundColor).toBe "rgba(0, 0, 255, 0)"
            expect(getStylesForGutterWithName(presenter, 'test-gutter').backgroundColor).toBe "rgba(0, 0, 255, 0)"

            expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 0, 0)")
            expect(getStylesForGutterWithName(presenter, 'line-number').backgroundColor).toBe "rgba(255, 0, 0, 0)"
            expect(getStylesForGutterWithName(presenter, 'test-gutter').backgroundColor).toBe "rgba(255, 0, 0, 0)"

            expectStateUpdate presenter, -> presenter.setBackgroundColor("rgba(0, 0, 255, 0)")
            expect(getStylesForGutterWithName(presenter, 'line-number').backgroundColor).toBe "rgba(0, 0, 255, 0)"
            expect(getStylesForGutterWithName(presenter, 'test-gutter').backgroundColor).toBe "rgba(0, 0, 255, 0)"

  # disabled until we fix an issue with display buffer markers not updating when
  # they are moved on screen but not in the buffer
  xdescribe "when the model and view measurements are mutated randomly", ->
    [editor, buffer, presenterParams, presenter, statements] = []

    recordStatement = (statement) -> statements.push(statement)

    it "correctly maintains the presenter state", ->
      _.times 20, ->
        waits(0)
        runs ->
          performSetup()
          performRandomInitialization(recordStatement)
          _.times 20, ->
            performRandomAction recordStatement
            expectValidState()
          performTeardown()

    xit "works correctly for a particular stream of random actions", ->
      performSetup()
      # paste output from failing spec here
      expectValidState()
      performTeardown()

    performSetup = ->
      buffer = new TextBuffer
      editor = atom.workspace.buildTextEditor({buffer})
      editor.setEditorWidthInChars(80)
      presenterParams =
        model: editor

      presenter = new TextEditorPresenter(presenterParams)
      statements = []

    performRandomInitialization = (log) ->
      actions = _.shuffle([
        changeScrollLeft
        changeScrollTop
        changeExplicitHeight
        changeContentFrameWidth
        changeLineHeight
        changeBaseCharacterWidth
        changeHorizontalScrollbarHeight
        changeVerticalScrollbarWidth
      ])
      for action in actions
        action(log)
        expectValidState()

    performTeardown = ->
      buffer.destroy()

    expectValidState = ->
      presenterParams.scrollTop = presenter.scrollTop
      presenterParams.scrollLeft = presenter.scrollLeft
      actualState = getState(presenter)
      expectedState = new TextEditorPresenter(presenterParams).state
      delete actualState.content.scrollingVertically
      delete expectedState.content.scrollingVertically

      unless _.isEqual(actualState, expectedState)
        console.log "Presenter states differ >>>>>>>>>>>>>>>>"
        console.log "Actual:", actualState
        console.log "Expected:", expectedState
        console.log "Uncomment code below this line to see a JSON diff"
        # {diff} = require 'json-diff' # !!! Run `npm install json-diff` in your `atom/` repository
        # console.log "Difference:", diff(actualState, expectedState)
        if statements.length > 0
          console.log """
            =====================================================
            Paste this code into the disabled spec in this file (and enable it) to repeat this failure:

            #{statements.join('\n')}
            =====================================================
          """
        throw new Error("Unexpected presenter state after random mutation. Check console output for details.")

    performRandomAction = (log) ->
      getRandomElement([
        changeScrollLeft
        changeScrollTop
        toggleSoftWrap
        insertText
        changeCursors
        changeSelections
        changeLineDecorations
      ])(log)

    changeScrollTop = (log) ->
      scrollHeight = (presenterParams.lineHeight ? 10) * editor.getScreenLineCount()
      explicitHeight = (presenterParams.explicitHeight ? 500)
      newScrollTop = Math.max(0, _.random(0, scrollHeight - explicitHeight))
      log "presenter.setScrollTop(#{newScrollTop})"
      presenter.setScrollTop(newScrollTop)

    changeScrollLeft = (log) ->
      scrollWidth = presenter.scrollWidth ? 300
      contentFrameWidth = presenter.contentFrameWidth ? 200
      newScrollLeft = Math.max(0, _.random(0, scrollWidth - contentFrameWidth))
      log """
        presenterParams.scrollLeft = #{newScrollLeft}
        presenter.setScrollLeft(#{newScrollLeft})
      """
      presenterParams.scrollLeft = newScrollLeft
      presenter.setScrollLeft(newScrollLeft)

    changeExplicitHeight = (log) ->
      scrollHeight = (presenterParams.lineHeight ? 10) * editor.getScreenLineCount()
      newExplicitHeight = _.random(30, scrollHeight * 1.5)
      log """
        presenterParams.explicitHeight = #{newExplicitHeight}
        presenter.setExplicitHeight(#{newExplicitHeight})
      """
      presenterParams.explicitHeight = newExplicitHeight
      presenter.setExplicitHeight(newExplicitHeight)

    changeContentFrameWidth = (log) ->
      scrollWidth = presenter.scrollWidth ? 300
      newContentFrameWidth = _.random(100, scrollWidth * 1.5)
      log """
        presenterParams.contentFrameWidth = #{newContentFrameWidth}
        presenter.setContentFrameWidth(#{newContentFrameWidth})
      """
      presenterParams.contentFrameWidth = newContentFrameWidth
      presenter.setContentFrameWidth(newContentFrameWidth)

    changeLineHeight = (log) ->
      newLineHeight = _.random(5, 15)
      log """
        presenterParams.lineHeight = #{newLineHeight}
        presenter.setLineHeight(#{newLineHeight})
      """
      presenterParams.lineHeight = newLineHeight
      presenter.setLineHeight(newLineHeight)

    changeBaseCharacterWidth = (log) ->
      newBaseCharacterWidth = _.random(5, 15)
      log """
        presenterParams.baseCharacterWidth = #{newBaseCharacterWidth}
        presenter.setBaseCharacterWidth(#{newBaseCharacterWidth})
      """
      presenterParams.baseCharacterWidth = newBaseCharacterWidth
      presenter.setBaseCharacterWidth(newBaseCharacterWidth)

    changeHorizontalScrollbarHeight = (log) ->
      newHorizontalScrollbarHeight = _.random(2, 15)
      log """
        presenterParams.horizontalScrollbarHeight = #{newHorizontalScrollbarHeight}
        presenter.setHorizontalScrollbarHeight(#{newHorizontalScrollbarHeight})
      """
      presenterParams.horizontalScrollbarHeight = newHorizontalScrollbarHeight
      presenter.setHorizontalScrollbarHeight(newHorizontalScrollbarHeight)

    changeVerticalScrollbarWidth = (log) ->
      newVerticalScrollbarWidth = _.random(2, 15)
      log """
        presenterParams.verticalScrollbarWidth = #{newVerticalScrollbarWidth}
        presenter.setVerticalScrollbarWidth(#{newVerticalScrollbarWidth})
      """
      presenterParams.verticalScrollbarWidth = newVerticalScrollbarWidth
      presenter.setVerticalScrollbarWidth(newVerticalScrollbarWidth)

    toggleSoftWrap = (log) ->
      softWrapped = not editor.isSoftWrapped()
      log "editor.setSoftWrapped(#{softWrapped})"
      editor.setSoftWrapped(softWrapped)

    insertText = (log) ->
      range = buildRandomRange()
      text = buildRandomText()
      log "editor.setTextInBufferRange(#{JSON.stringify(range.serialize())}, #{JSON.stringify(text)})"
      editor.setTextInBufferRange(range, text)

    changeCursors = (log) ->
      actions = [addCursor, moveCursor]
      actions.push(destroyCursor) if editor.getCursors().length > 1
      getRandomElement(actions)(log)

    addCursor = (log) ->
      position = buildRandomPoint()
      log "editor.addCursorAtBufferPosition(#{JSON.stringify(position.serialize())})"
      editor.addCursorAtBufferPosition(position)

    moveCursor = (log) ->
      index = _.random(0, editor.getCursors().length - 1)
      position = buildRandomPoint()
      log """
        cursor = editor.getCursors()[#{index}]
        cursor.selection.clear()
        cursor.setBufferPosition(#{JSON.stringify(position.serialize())})
      """
      cursor = editor.getCursors()[index]
      cursor.selection.clear()
      cursor.setBufferPosition(position)

    destroyCursor = (log) ->
      index = _.random(0, editor.getCursors().length - 1)
      log "editor.getCursors()[#{index}].destroy()"
      editor.getCursors()[index].destroy()

    changeSelections = (log) ->
      actions = [addSelection, changeSelection]
      actions.push(destroySelection) if editor.getSelections().length > 1
      getRandomElement(actions)(log)

    addSelection = (log) ->
      range = buildRandomRange()
      log "editor.addSelectionForBufferRange(#{JSON.stringify(range.serialize())})"
      editor.addSelectionForBufferRange(range)

    changeSelection = (log) ->
      index = _.random(0, editor.getSelections().length - 1)
      range = buildRandomRange()
      log "editor.getSelections()[#{index}].setBufferRange(#{JSON.stringify(range.serialize())})"
      editor.getSelections()[index].setBufferRange(range)

    destroySelection = (log) ->
      index = _.random(0, editor.getSelections().length - 1)
      log "editor.getSelections()[#{index}].destroy()"
      editor.getSelections()[index].destroy()

    changeLineDecorations = (log) ->
      actions = [addLineDecoration]
      actions.push(changeLineDecoration, destroyLineDecoration) if editor.getLineDecorations().length > 0
      getRandomElement(actions)(log)

    addLineDecoration = (log) ->
      range = buildRandomRange()
      options = {
        type: getRandomElement(['line', 'line-number'])
        class: randomWords(exactly: 1)[0]
      }
      if Math.random() > .2
        options.onlyEmpty = true
      else if Math.random() > .2
        options.onlyNonEmpty = true
      else if Math.random() > .2
        options.onlyHead = true

      log """
        marker = editor.markBufferRange(#{JSON.stringify(range.serialize())})
        editor.decorateMarker(marker, #{JSON.stringify(options)})
      """

      marker = editor.markBufferRange(range)
      editor.decorateMarker(marker, options)

    changeLineDecoration = (log) ->
      index = _.random(0, editor.getLineDecorations().length - 1)
      range = buildRandomRange()
      log "editor.getLineDecorations()[#{index}].getMarker().setBufferRange(#{JSON.stringify(range.serialize())})"
      editor.getLineDecorations()[index].getMarker().setBufferRange(range)

    destroyLineDecoration = (log) ->
      index = _.random(0, editor.getLineDecorations().length - 1)
      log "editor.getLineDecorations()[#{index}].destroy()"
      editor.getLineDecorations()[index].destroy()

    buildRandomPoint = ->
      row = _.random(0, buffer.getLastRow())
      column = _.random(0, buffer.lineForRow(row).length)
      new Point(row, column)

    buildRandomRange = ->
      new Range(buildRandomPoint(), buildRandomPoint())

    buildRandomText = ->
      text = []

      _.times _.random(20, 60), ->
        if Math.random() < .2
          text += '\n'
        else
          text += " " if /\w$/.test(text)
          text += randomWords(exactly: 1)
      text

    getRandomElement = (array) ->
      array[Math.floor(Math.random() * array.length)]
