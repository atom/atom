_ = require 'underscore-plus'
randomWords = require 'random-words'
TextBuffer = require 'text-buffer'
{Point, Range} = TextBuffer
TextEditor = require '../src/text-editor'
TextEditorPresenter = require '../src/text-editor-presenter'

describe "TextEditorPresenter", ->
  # These `describe` and `it` blocks mirror the structure of the ::state object.
  # Please maintain this structure when adding specs for new state fields.
  describe "::getState()", ->
    [buffer, editor] = []

    beforeEach ->
      # These *should* be mocked in the spec helper, but changing that now would break packages :-(
      spyOn(window, "setInterval").andCallFake window.fakeSetInterval
      spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

      buffer = new TextBuffer(filePath: require.resolve('./fixtures/sample.js'))
      editor = new TextEditor({buffer})
      waitsForPromise -> buffer.load()

    afterEach ->
      editor.destroy()
      buffer.destroy()

    buildPresenter = (params={}) ->
      _.defaults params,
        model: editor
        explicitHeight: 130
        contentFrameWidth: 500
        windowWidth: 500
        windowHeight: 130
        boundingClientRect: {left: 0, top: 0, width: 500, height: 130}
        lineHeight: 10
        baseCharacterWidth: 10
        horizontalScrollbarHeight: 10
        verticalScrollbarWidth: 10
        scrollTop: 0
        scrollLeft: 0
        lineOverdrawMargin: 0

      new TextEditorPresenter(params)

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

    describe "during state retrieval", ->
      it "does not trigger onDidUpdateState events", ->
        presenter = buildPresenter()
        expectNoStateUpdate presenter, -> presenter.getState()

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

          expect(presenter.getState().horizontalScrollbar.visible).toBe false

          # ::contentFrameWidth itself is smaller than scrollWidth
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(presenter.getState().horizontalScrollbar.visible).toBe true

          # restore...
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10 + 1)
          expect(presenter.getState().horizontalScrollbar.visible).toBe false

          # visible vertical scrollbar makes the clientWidth smaller than the scrollWidth
          presenter.setExplicitHeight((editor.getLineCount() * 10) - 1)
          expect(presenter.getState().horizontalScrollbar.visible).toBe true

        it "is false if the editor is mini", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 - 10
            baseCharacterWidth: 10

          expect(presenter.getState().horizontalScrollbar.visible).toBe true
          editor.setMini(true)
          expect(presenter.getState().horizontalScrollbar.visible).toBe false
          editor.setMini(false)
          expect(presenter.getState().horizontalScrollbar.visible).toBe true

      describe ".height", ->
        it "tracks the value of ::horizontalScrollbarHeight", ->
          presenter = buildPresenter(horizontalScrollbarHeight: 10)
          expect(presenter.getState().horizontalScrollbar.height).toBe 10
          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(20)
          expect(presenter.getState().horizontalScrollbar.height).toBe 20

      describe ".right", ->
        it "is ::verticalScrollbarWidth if the vertical scrollbar is visible and 0 otherwise", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10 + 50
            contentFrameWidth: editor.getMaxScreenLineLength() * 10
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(presenter.getState().horizontalScrollbar.right).toBe 0
          presenter.setExplicitHeight((editor.getLineCount() * 10) - 1)
          expect(presenter.getState().horizontalScrollbar.right).toBe 10

      describe ".scrollWidth", ->
        it "is initialized as the max of the ::contentFrameWidth and the width of the longest line", ->
          maxLineLength = editor.getMaxScreenLineLength()

          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1

          presenter = buildPresenter(contentFrameWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::contentFrameWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setContentFrameWidth(10 * maxLineLength + 20)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::baseCharacterWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(15)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 15 * maxLineLength + 1

        it "updates when the scoped character widths change", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            maxLineLength = editor.getMaxScreenLineLength()
            presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

            expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * maxLineLength + 1
            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'support.function.js'], 'p', 20)
            expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

        it "updates when ::softWrapped changes on the editor", ->
          presenter = buildPresenter(contentFrameWidth: 470, baseCharacterWidth: 10)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
          expectStateUpdate presenter, -> editor.setSoftWrapped(true)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe presenter.clientWidth
          expectStateUpdate presenter, -> editor.setSoftWrapped(false)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "updates when the longest line changes", ->
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([editor.getLongestScreenRow(), 0])
          expectStateUpdate presenter, -> editor.insertText('xyz')

          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

      describe ".scrollLeft", ->
        it "tracks the value of ::scrollLeft", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe 50

        it "never exceeds the computed scrollWidth minus the computed clientWidth", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, explicitHeight: 100, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(300)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setContentFrameWidth(600)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(5)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> editor.getBuffer().delete([[6, 0], [6, Infinity]])
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollLeftBefore = presenter.getState().horizontalScrollbar.scrollLeft
          expectStateUpdate presenter, -> editor.getBuffer().insert([6, 0], new Array(100).join('x'))
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe scrollLeftBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(-300)
          expect(presenter.getState().horizontalScrollbar.scrollLeft).toBe 0

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

          expect(presenter.getState().verticalScrollbar.visible).toBe false

          # ::explicitHeight itself is smaller than scrollWidth
          presenter.setExplicitHeight(editor.getLineCount() * 10 - 1)
          expect(presenter.getState().verticalScrollbar.visible).toBe true

          # restore...
          presenter.setExplicitHeight(editor.getLineCount() * 10)
          expect(presenter.getState().verticalScrollbar.visible).toBe false

          # visible horizontal scrollbar makes the clientHeight smaller than the scrollHeight
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(presenter.getState().verticalScrollbar.visible).toBe true

      describe ".width", ->
        it "is assigned based on ::verticalScrollbarWidth", ->
          presenter = buildPresenter(verticalScrollbarWidth: 10)
          expect(presenter.getState().verticalScrollbar.width).toBe 10
          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(20)
          expect(presenter.getState().verticalScrollbar.width).toBe 20

      describe ".bottom", ->
        it "is ::horizontalScrollbarHeight if the horizontal scrollbar is visible and 0 otherwise", ->
          presenter = buildPresenter
            explicitHeight: editor.getLineCount() * 10 - 1
            contentFrameWidth: editor.getMaxScreenLineLength() * 10 + 50
            baseCharacterWidth: 10
            lineHeight: 10
            horizontalScrollbarHeight: 10
            verticalScrollbarWidth: 10

          expect(presenter.getState().verticalScrollbar.bottom).toBe 0
          presenter.setContentFrameWidth(editor.getMaxScreenLineLength() * 10)
          expect(presenter.getState().verticalScrollbar.bottom).toBe 10

      describe ".scrollHeight", ->
        it "is initialized based on the lineHeight, the number of lines, and the height", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 500)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe 500

        it "updates when the ::lineHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe 500

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe presenter.contentHeight

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().verticalScrollbar.scrollHeight).toBe presenter.contentHeight

      describe ".scrollTop", ->
        it "tracks the value of ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 20, horizontalScrollbarHeight: 10)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe 50

        it "never exceeds the computed scrollHeight minus the computed clientHeight", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(100)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollTopBefore = presenter.getState().verticalScrollbar.scrollTop
          expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe scrollTopBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(-100)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe 0

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

          atom.config.set("editor.scrollPastEnd", true)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().verticalScrollbar.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

    describe ".hiddenInput", ->
      describe ".top/.left", ->
        it "is positioned over the last cursor it is in view and the editor is focused", ->
          editor.setCursorBufferPosition([3, 6])
          presenter = buildPresenter(focused: false, explicitHeight: 50, contentFrameWidth: 300, horizontalScrollbarHeight: 0, verticalScrollbarWidth: 0)
          expectValues presenter.getState().hiddenInput, {top: 0, left: 0}

          expectStateUpdate presenter, -> presenter.setFocused(true)
          expectValues presenter.getState().hiddenInput, {top: 3 * 10, left: 6 * 10}

          expectStateUpdate presenter, -> presenter.setScrollTop(15)
          expectValues presenter.getState().hiddenInput, {top: (3 * 10) - 15, left: 6 * 10}

          expectStateUpdate presenter, -> presenter.setScrollLeft(35)
          expectValues presenter.getState().hiddenInput, {top: (3 * 10) - 15, left: (6 * 10) - 35}

          expectStateUpdate presenter, -> presenter.setScrollTop(40)
          expectValues presenter.getState().hiddenInput, {top: 0, left: (6 * 10) - 35}

          expectStateUpdate presenter, -> presenter.setScrollLeft(70)
          expectValues presenter.getState().hiddenInput, {top: 0, left: 0}

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([11, 43])
          expectValues presenter.getState().hiddenInput, {top: 11 * 10 - editor.getScrollTop(), left: 43 * 10 - editor.getScrollLeft()}

          newCursor = null
          expectStateUpdate presenter, -> newCursor = editor.addCursorAtBufferPosition([6, 10])
          expectValues presenter.getState().hiddenInput, {top: (6 * 10) - editor.getScrollTop(), left: (10 * 10) - editor.getScrollLeft()}

          expectStateUpdate presenter, -> newCursor.destroy()
          expectValues presenter.getState().hiddenInput, {top: 50 - 10, left: 300 - 10}

          expectStateUpdate presenter, -> presenter.setFocused(false)
          expectValues presenter.getState().hiddenInput, {top: 0, left: 0}

      describe ".height", ->
        it "is assigned based on the line height", ->
          presenter = buildPresenter()
          expect(presenter.getState().hiddenInput.height).toBe 10

          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(presenter.getState().hiddenInput.height).toBe 20

      describe ".width", ->
        it "is assigned based on the width of the character following the cursor", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setCursorBufferPosition([3, 6])
            presenter = buildPresenter()
            expect(presenter.getState().hiddenInput.width).toBe 10

            expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(15)
            expect(presenter.getState().hiddenInput.width).toBe 15

            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'storage.modifier.js'], 'r', 20)
            expect(presenter.getState().hiddenInput.width).toBe 20

        it "is 2px at the end of lines", ->
          presenter = buildPresenter()
          editor.setCursorBufferPosition([3, Infinity])
          expect(presenter.getState().hiddenInput.width).toBe 2

    describe ".content", ->
      describe ".scrollingVertically", ->
        it "is true for ::stoppedScrollingDelay milliseconds following a changes to ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, stoppedScrollingDelay: 200, explicitHeight: 100)
          expect(presenter.getState().content.scrollingVertically).toBe false
          expectStateUpdate presenter, -> presenter.setScrollTop(0)
          expect(presenter.getState().content.scrollingVertically).toBe true
          advanceClock(100)
          expect(presenter.getState().content.scrollingVertically).toBe true
          presenter.setScrollTop(10)
          advanceClock(100)
          expect(presenter.getState().content.scrollingVertically).toBe true
          expectStateUpdate presenter, -> advanceClock(100)
          expect(presenter.getState().content.scrollingVertically).toBe false

      describe ".scrollHeight", ->
        it "is initialized based on the lineHeight, the number of lines, and the height", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expect(presenter.getState().content.scrollHeight).toBe editor.getScreenLineCount() * 10

          presenter = buildPresenter(scrollTop: 0, lineHeight: 10, explicitHeight: 500)
          expect(presenter.getState().content.scrollHeight).toBe 500

        it "updates when the ::lineHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(presenter.getState().content.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(presenter.getState().content.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter(scrollTop: 0, lineHeight: 10)
          expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
          expect(presenter.getState().content.scrollHeight).toBe 500

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().content.scrollHeight).toBe presenter.contentHeight

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
          expect(presenter.getState().content.scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().content.scrollHeight).toBe presenter.contentHeight

      describe ".scrollWidth", ->
        it "is initialized as the max of the computed clientWidth and the width of the longest line", ->
          maxLineLength = editor.getMaxScreenLineLength()

          presenter = buildPresenter(explicitHeight: 100, contentFrameWidth: 50, baseCharacterWidth: 10, verticalScrollbarWidth: 10)
          expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 1

          presenter = buildPresenter(explicitHeight: 100, contentFrameWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10, verticalScrollbarWidth: 10)
          expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 20 - 10 # subtract vertical scrollbar width

        it "updates when the ::contentFrameWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setContentFrameWidth(10 * maxLineLength + 20)
          expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::baseCharacterWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(15)
          expect(presenter.getState().content.scrollWidth).toBe 15 * maxLineLength + 1

        it "updates when the scoped character widths change", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            maxLineLength = editor.getMaxScreenLineLength()
            presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

            expect(presenter.getState().content.scrollWidth).toBe 10 * maxLineLength + 1
            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'support.function.js'], 'p', 20)
            expect(presenter.getState().content.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

        it "updates when ::softWrapped changes on the editor", ->
          presenter = buildPresenter(contentFrameWidth: 470, baseCharacterWidth: 10)
          expect(presenter.getState().content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
          expectStateUpdate presenter, -> editor.setSoftWrapped(true)
          expect(presenter.getState().horizontalScrollbar.scrollWidth).toBe presenter.clientWidth
          expectStateUpdate presenter, -> editor.setSoftWrapped(false)
          expect(presenter.getState().content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

        it "updates when the longest line changes", ->
          presenter = buildPresenter(contentFrameWidth: 50, baseCharacterWidth: 10)

          expect(presenter.getState().content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

          expectStateUpdate presenter, -> editor.setCursorBufferPosition([editor.getLongestScreenRow(), 0])
          expectStateUpdate presenter, -> editor.insertText('xyz')

          expect(presenter.getState().content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

      describe ".scrollTop", ->
        it "tracks the value of ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, lineHeight: 10, explicitHeight: 20)
          expect(presenter.getState().content.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(presenter.getState().content.scrollTop).toBe 50

        it "never exceeds the computed scroll height minus the computed client height", ->
          presenter = buildPresenter(scrollTop: 10, lineHeight: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(100)
          expect(presenter.getState().content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(presenter.getState().content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
          expect(presenter.getState().content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
          expect(presenter.getState().content.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollTopBefore = presenter.getState().verticalScrollbar.scrollTop
          expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
          expect(presenter.getState().content.scrollTop).toBe scrollTopBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(-100)
          expect(presenter.getState().content.scrollTop).toBe 0

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().content.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

          atom.config.set("editor.scrollPastEnd", true)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().content.scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().content.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

      describe ".scrollLeft", ->
        it "tracks the value of ::scrollLeft", ->
          presenter = buildPresenter(scrollLeft: 10, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expect(presenter.getState().content.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          expect(presenter.getState().content.scrollLeft).toBe 50

        it "never exceeds the computed scrollWidth minus the computed clientWidth", ->
          presenter = buildPresenter(scrollLeft: 10, lineHeight: 10, baseCharacterWidth: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(300)
          expect(presenter.getState().content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setContentFrameWidth(600)
          expect(presenter.getState().content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> presenter.setVerticalScrollbarWidth(5)
          expect(presenter.getState().content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          expectStateUpdate presenter, -> editor.getBuffer().delete([[6, 0], [6, Infinity]])
          expect(presenter.getState().content.scrollLeft).toBe presenter.scrollWidth - presenter.clientWidth

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollLeftBefore = presenter.getState().content.scrollLeft
          expectStateUpdate presenter, -> editor.getBuffer().insert([6, 0], new Array(100).join('x'))
          expect(presenter.getState().content.scrollLeft).toBe scrollLeftBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollLeft: 10, verticalScrollbarWidth: 10, contentFrameWidth: 500)
          expectStateUpdate presenter, -> presenter.setScrollLeft(-300)
          expect(presenter.getState().content.scrollLeft).toBe 0

      describe ".indentGuidesVisible", ->
        it "is initialized based on the editor.showIndentGuide config setting", ->
          presenter = buildPresenter()
          expect(presenter.getState().content.indentGuidesVisible).toBe false

          atom.config.set('editor.showIndentGuide', true)
          presenter = buildPresenter()
          expect(presenter.getState().content.indentGuidesVisible).toBe true

        it "updates when the editor.showIndentGuide config setting changes", ->
          presenter = buildPresenter()
          expect(presenter.getState().content.indentGuidesVisible).toBe false

          expectStateUpdate presenter, -> atom.config.set('editor.showIndentGuide', true)
          expect(presenter.getState().content.indentGuidesVisible).toBe true

          expectStateUpdate presenter, -> atom.config.set('editor.showIndentGuide', false)
          expect(presenter.getState().content.indentGuidesVisible).toBe false

        it "updates when the editor's grammar changes", ->
          atom.config.set('editor.showIndentGuide', true, scopeSelector: ".source.js")

          presenter = buildPresenter()
          expect(presenter.getState().content.indentGuidesVisible).toBe false

          stateUpdated = false
          presenter.onDidUpdateState -> stateUpdated = true

          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            expect(stateUpdated).toBe true
            expect(presenter.getState().content.indentGuidesVisible).toBe true

            expectStateUpdate presenter, -> editor.setGrammar(atom.grammars.selectGrammar('.txt'))
            expect(presenter.getState().content.indentGuidesVisible).toBe false

        it "is always false when the editor is mini", ->
          atom.config.set('editor.showIndentGuide', true)
          editor.setMini(true)
          presenter = buildPresenter()
          expect(presenter.getState().content.indentGuidesVisible).toBe false
          editor.setMini(false)
          expect(presenter.getState().content.indentGuidesVisible).toBe true
          editor.setMini(true)
          expect(presenter.getState().content.indentGuidesVisible).toBe false

      describe ".backgroundColor", ->
        it "is assigned to ::backgroundColor unless the editor is mini", ->
          presenter = buildPresenter(backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.getState().content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          editor.setMini(true)
          presenter = buildPresenter(backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.getState().content.backgroundColor).toBeNull()

        it "updates when ::backgroundColor changes", ->
          presenter = buildPresenter(backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.getState().content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> presenter.setBackgroundColor('rgba(0, 0, 255, 0)')
          expect(presenter.getState().content.backgroundColor).toBe 'rgba(0, 0, 255, 0)'

        it "updates when ::mini changes", ->
          presenter = buildPresenter(backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.getState().content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> editor.setMini(true)
          expect(presenter.getState().content.backgroundColor).toBeNull()

      describe ".placeholderText", ->
        it "is present when the editor has no text", ->
          editor.setPlaceholderText("the-placeholder-text")
          presenter = buildPresenter()
          expect(presenter.getState().content.placeholderText).toBeNull()

          expectStateUpdate presenter, -> editor.setText("")
          expect(presenter.getState().content.placeholderText).toBe "the-placeholder-text"

          expectStateUpdate presenter, -> editor.setPlaceholderText("new-placeholder-text")
          expect(presenter.getState().content.placeholderText).toBe "new-placeholder-text"

      describe ".lines", ->
        lineStateForScreenRow = (presenter, screenRow) ->
          presenter.getState().content.lines[presenter.model.tokenizedLineForScreenRow(screenRow).id]

        it "contains states for lines that are visible on screen, plus and minus the overdraw margin", ->
          presenter = buildPresenter(explicitHeight: 15, scrollTop: 50, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineStateForScreenRow(presenter, 3)).toBeUndefined()

          line4 = editor.tokenizedLineForScreenRow(4)
          expectValues lineStateForScreenRow(presenter, 4), {
            screenRow: 4
            text: line4.text
            tokens: line4.tokens
            top: 10 * 4
          }

          line5 = editor.tokenizedLineForScreenRow(5)
          expectValues lineStateForScreenRow(presenter, 5), {
            screenRow: 5
            text: line5.text
            tokens: line5.tokens
            top: 10 * 5
          }

          line6 = editor.tokenizedLineForScreenRow(6)
          expectValues lineStateForScreenRow(presenter, 6), {
            screenRow: 6
            text: line6.text
            tokens: line6.tokens
            top: 10 * 6
          }

          line7 = editor.tokenizedLineForScreenRow(7)
          expectValues lineStateForScreenRow(presenter, 7), {
            screenRow: 7
            text: line7.text
            tokens: line7.tokens
            top: 10 * 7
          }

          line8 = editor.tokenizedLineForScreenRow(8)
          expectValues lineStateForScreenRow(presenter, 8), {
            screenRow: 8
            text: line8.text
            tokens: line8.tokens
            top: 10 * 8
          }

          expect(lineStateForScreenRow(presenter, 9)).toBeUndefined()

        it "does not overdraw above the first row", ->
          presenter = buildPresenter(explicitHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 2)
          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 3)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

        it "does not overdraw below the last row", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 105, lineHeight: 10, lineOverdrawMargin: 2)
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 8)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 9)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 10)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 11)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

        it "includes state for all lines if no external ::explicitHeight is assigned", ->
          presenter = buildPresenter(explicitHeight: null)
          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

        it "is empty until all of the required measurements are assigned", ->
          presenter = buildPresenter(explicitHeight: null, lineHeight: null, scrollTop: null)
          expect(presenter.getState().content.lines).toEqual({})

          presenter.setExplicitHeight(25)
          expect(presenter.getState().content.lines).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.getState().content.lines).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.getState().content.lines).not.toEqual({})

        it "updates when ::scrollTop changes", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setScrollTop(25)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter(explicitHeight: 15, scrollTop: 15, lineHeight: 10, lineOverdrawMargin: 1)

          line5 = editor.tokenizedLineForScreenRow(5)

          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setExplicitHeight(35)

          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          presenter = buildPresenter(explicitHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

        it "updates when the editor's content changes", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 10, lineHeight: 10)

          expectStateUpdate presenter, -> buffer.insert([2, 0], "hello\nworld\n")

          line1 = editor.tokenizedLineForScreenRow(1)
          expectValues lineStateForScreenRow(presenter, 1), {
            text: line1.text
            tokens: line1.tokens
          }

          line2 = editor.tokenizedLineForScreenRow(2)
          expectValues lineStateForScreenRow(presenter, 2), {
            text: line2.text
            tokens: line2.tokens
          }

          line3 = editor.tokenizedLineForScreenRow(3)
          expectValues lineStateForScreenRow(presenter, 3), {
            text: line3.text
            tokens: line3.tokens
          }

        it "does not remove out-of-view lines corresponding to ::mouseWheelScreenRow until ::stoppedScrollingDelay elapses", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1, stoppedScrollingDelay: 200)

          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

          presenter.setMouseWheelScreenRow(0)
          expectStateUpdate presenter, -> presenter.setScrollTop(35)

          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> advanceClock(200)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 8)).toBeUndefined()

          # should clear ::mouseWheelScreenRow after stoppedScrollingDelay elapses even if we don't scroll first
          presenter.setMouseWheelScreenRow(2)
          advanceClock(200)
          expectStateUpdate presenter, -> presenter.setScrollTop(45)
          expect(lineStateForScreenRow(presenter, 2)).toBeUndefined()

        it "does not preserve on-screen lines even if they correspond to ::mouseWheelScreenRow", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1, stoppedScrollingDelay: 200)
          oldLine3 = editor.tokenizedLineForScreenRow(6)

          presenter.setMouseWheelScreenRow(3)

          expectStateUpdate presenter, -> editor.getBuffer().insert([3, Infinity], 'xyz')
          newLine3 = editor.tokenizedLineForScreenRow(3)

          expect(presenter.getState().content.lines[oldLine3.id]).toBeUndefined()
          expect(presenter.getState().content.lines[newLine3.id]).toBeDefined()

        it "does not attempt to preserve lines corresponding to ::mouseWheelScreenRow if they have been deleted", ->
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1, stoppedScrollingDelay: 200)
          presenter.setMouseWheelScreenRow(10)
          editor.setText('')

        describe "[lineId]", -> # line state objects
          it "includes the .endOfLineInvisibles if the editor.showInvisibles config option is true", ->
            editor.setText("hello\nworld\r\n")
            presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10)
            expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toBeNull()
            expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toBeNull()

            atom.config.set('editor.showInvisibles', true)
            presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineHeight: 10)
            expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.eol')]
            expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.cr'), atom.config.get('editor.invisibles.eol')]

          describe ".decorationClasses", ->
            it "adds decoration classes to the relevant line state objects, both initially and when decorations change", ->
              marker1 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration1 = editor.decorateMarker(marker1, type: 'line', class: 'a')
              presenter = buildPresenter()
              marker2 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration2 = editor.decorateMarker(marker2, type: 'line', class: 'b')

              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
              expect(marker1.isValid()).toBe false
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.undo()
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> decoration1.destroy()
              expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> marker2.destroy()
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

              expectStateUpdate presenter, -> marker.clearTail()

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

              expectStateUpdate presenter, -> marker.clearTail()

              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "honors the 'onlyHead' option on line decorations", ->
              presenter = buildPresenter()
              marker = editor.markBufferRange([[4, 0], [6, 2]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyHead: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            it "does not decorate the last line of a non-empty line decoration range if it ends at column 0", ->
              presenter = buildPresenter()
              marker = editor.markBufferRange([[4, 0], [6, 0]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a')

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "does not apply line decorations to mini editors", ->
              editor.setMini(true)
              presenter = buildPresenter(explicitHeight: 10)
              marker = editor.markBufferRange([[0, 0], [0, 0]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a')
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.setMini(false)
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'a']

              expectStateUpdate presenter, -> editor.setMini(true)
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

            it "only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
              editor.setText("a line that wraps, ok")
              editor.setSoftWrapped(true)
              editor.setEditorWidthInChars(16)
              marker = editor.markBufferRange([[0, 0], [0, 2]])
              editor.decorateMarker(marker, type: 'line', class: 'a')
              presenter = buildPresenter(explicitHeight: 10)

              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

              marker.setBufferRange([[0, 0], [0, Infinity]])
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

      describe ".cursors", ->
        stateForCursor = (presenter, cursorIndex) ->
          presenter.getState().content.cursors[presenter.model.getCursors()[cursorIndex].id]

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
          expect(stateForCursor(presenter, 1)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toBeUndefined()

        it "is empty until all of the required measurements are assigned", ->
          presenter = buildPresenter(explicitHeight: null, lineHeight: null, scrollTop: null, baseCharacterWidth: null, horizontalScrollbarHeight: null)
          expect(presenter.getState().content.cursors).toEqual({})

          presenter.setExplicitHeight(25)
          expect(presenter.getState().content.cursors).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.getState().content.cursors).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.getState().content.cursors).toEqual({})

          presenter.setBaseCharacterWidth(8)
          expect(presenter.getState().content.cursors).toEqual({})

          presenter.setHorizontalScrollbarHeight(10)
          expect(presenter.getState().content.cursors).not.toEqual({})

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
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 10, left: 4 * 10, width: 10, height: 10}

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
          expect(stateForCursor(presenter, 1)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
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
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 5, left: 12 * 10, width: 10, height: 5}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 5, left: 4 * 10, width: 10, height: 5}

        it "updates when ::baseCharacterWidth changes", ->
          editor.setCursorBufferPosition([2, 4])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20)

          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(20)
          expect(stateForCursor(presenter, 0)).toEqual {top: 2 * 10, left: 4 * 20, width: 20, height: 10}

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setCursorBufferPosition([1, 4])
            presenter = buildPresenter(explicitHeight: 20)

            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'storage.modifier.js'], 'v', 20)
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10, left: (3 * 10) + 20, width: 10, height: 10}

            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'storage.modifier.js'], 'r', 20)
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
          expect(stateForCursor(presenter, 0)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}

          # showing
          expectStateUpdate presenter, -> editor.getSelections()[1].clear()
          expect(stateForCursor(presenter, 1)).toEqual {top: 3 * 10, left: 5 * 10, width: 10, height: 10}

          # hiding
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[3, 4], [3, 5]])
          expect(stateForCursor(presenter, 1)).toBeUndefined()

          # moving out of view
          expectStateUpdate presenter, -> editor.getCursors()[0].setBufferPosition([10, 4])
          expect(stateForCursor(presenter, 0)).toBeUndefined()

          # adding
          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([4, 4])
          expect(stateForCursor(presenter, 2)).toEqual {top: 4 * 10, left: 4 * 10, width: 10, height: 10}

          # moving added cursor
          expectStateUpdate presenter, -> editor.getCursors()[2].setBufferPosition([4, 6])
          expect(stateForCursor(presenter, 2)).toEqual {top: 4 * 10, left: 6 * 10, width: 10, height: 10}

          # destroying
          destroyedCursor = editor.getCursors()[2]
          expectStateUpdate presenter, -> destroyedCursor.destroy()
          expect(presenter.getState().content.cursors[destroyedCursor.id]).toBeUndefined()

        it "makes cursors as wide as the ::baseCharacterWidth if they're at the end of a line", ->
          editor.setCursorBufferPosition([1, Infinity])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)
          expect(stateForCursor(presenter, 0).width).toBe 10

      describe ".cursorsVisible", ->
        it "alternates between true and false twice per ::cursorBlinkPeriod when the editor is focused", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = buildPresenter({cursorBlinkPeriod, cursorBlinkResumeDelay, focused: true})

          expect(presenter.getState().content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe true

          expectStateUpdate presenter, -> presenter.setFocused(false)
          expect(presenter.getState().content.cursorsVisible).toBe false
          advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false
          advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> presenter.setFocused(true)
          expect(presenter.getState().content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false

        it "stops alternating for ::cursorBlinkResumeDelay when a cursor moves or a cursor is added", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = buildPresenter({cursorBlinkPeriod, cursorBlinkResumeDelay, focused: true})

          expect(presenter.getState().content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> editor.moveRight()
          expect(presenter.getState().content.cursorsVisible).toBe true

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)

          expect(presenter.getState().content.cursorsVisible).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false

          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([1, 0])
          expect(presenter.getState().content.cursorsVisible).toBe true

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.getState().content.cursorsVisible).toBe false

      describe ".highlights", ->
        stateForHighlight = (presenter, decoration) ->
          presenter.getState().content.highlights[decoration.id]

        stateForSelection = (presenter, selectionIndex) ->
          selection = presenter.model.getSelections()[selectionIndex]
          stateForHighlight(presenter, selection.decoration)

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

          # on-screen
          marker4 = editor.markBufferRange([[2, 6], [4, 6]])
          highlight4 = editor.decorateMarker(marker4, type: 'highlight', class: 'd')

          # partially off-screen below, 2 of 3 regions on screen
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

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expect(stateForHighlight(presenter, highlight1)).toBeUndefined()

          expectValues stateForHighlight(presenter, highlight2), {
            class: 'b'
            regions: [
              {top: 2 * 10, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight3), {
            class: 'c'
            regions: [
              {top: 2 * 10, left: 0 * 10, right: 0, height: 1 * 10}
              {top: 3 * 10, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight4), {
            class: 'd'
            regions: [
              {top: 2 * 10, left: 6 * 10, right: 0, height: 1 * 10}
              {top: 3 * 10, left: 0, right: 0, height: 1 * 10}
              {top: 4 * 10, left: 0, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight5), {
            class: 'e'
            regions: [
              {top: 3 * 10, left: 6 * 10, right: 0, height: 1 * 10}
              {top: 4 * 10, left: 0 * 10, right: 0, height: 2 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight6), {
            class: 'f'
            regions: [
              {top: 5 * 10, left: 6 * 10, right: 0, height: 1 * 10}
            ]
          }

          expect(stateForHighlight(presenter, highlight7)).toBeUndefined()
          expect(stateForHighlight(presenter, highlight8)).toBeUndefined()

        it "is empty until all of the required measurements are assigned", ->
          editor.setSelectedBufferRanges([
            [[0, 2], [2, 4]],
          ])

          presenter = buildPresenter(explicitHeight: null, lineHeight: null, scrollTop: null, baseCharacterWidth: null)
          expect(presenter.getState().content.highlights).toEqual({})

          presenter.setExplicitHeight(25)
          expect(presenter.getState().content.highlights).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.getState().content.highlights).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.getState().content.highlights).toEqual({})

          presenter.setBaseCharacterWidth(8)
          expect(presenter.getState().content.highlights).not.toEqual({})

        it "does not include highlights for invalid markers", ->
          marker = editor.markBufferRange([[2, 2], [2, 4]], invalidate: 'touch')
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'h')

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expect(stateForHighlight(presenter, highlight)).toBeDefined()
          expectStateUpdate presenter, -> editor.getBuffer().insert([2, 2], "stuff")
          expect(stateForHighlight(presenter, highlight)).toBeUndefined()

        it "updates when ::scrollTop changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expect(stateForSelection(presenter, 0)).toBeUndefined()
          expectStateUpdate presenter, -> presenter.setScrollTop(5 * 10)
          expect(stateForSelection(presenter, 0)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setScrollTop(2 * 10)
          expect(stateForSelection(presenter, 0)).toBeUndefined()

        it "updates when ::explicitHeight changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = buildPresenter(explicitHeight: 20, scrollTop: 20)

          expect(stateForSelection(presenter, 0)).toBeUndefined()
          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(stateForSelection(presenter, 0)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setExplicitHeight(20)
          expect(stateForSelection(presenter, 0)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 4]],
            [[3, 4], [3, 6]],
          ])

          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)

          expectValues stateForSelection(presenter, 0), {
            regions: [
              {top: 2 * 10, left: 2 * 10, width: 2 * 10, height: 10}
            ]
          }
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues stateForSelection(presenter, 0), {
            regions: [
              {top: 2 * 5, left: 2 * 10, width: 2 * 10, height: 5}
            ]
          }

          expectValues stateForSelection(presenter, 1), {
            regions: [
              {top: 3 * 5, left: 4 * 10, width: 2 * 10, height: 5}
            ]
          }

        it "updates when ::baseCharacterWidth changes", ->
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 4]],
          ])

          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)

          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 2 * 10, left: 2 * 10, width: 2 * 10, height: 10}]
          }
          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(20)
          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 2 * 10, left: 2 * 20, width: 2 * 20, height: 10}]
          }

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setSelectedBufferRanges([
              [[2, 4], [2, 6]],
            ])

            presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)

            expectValues stateForSelection(presenter, 0), {
              regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
            }
            expectStateUpdate presenter, -> presenter.setScopedCharacterWidth(['source.js', 'keyword.control.js'], 'i', 20)
            expectValues stateForSelection(presenter, 0), {
              regions: [{top: 2 * 10, left: 4 * 10, width: 20 + 10, height: 10}]
            }

        it "updates when highlight decorations are added, moved, hidden, shown, or destroyed", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 4]],
            [[3, 4], [3, 6]]
          ])
          presenter = buildPresenter(explicitHeight: 20, scrollTop: 0)

          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 1 * 10, left: 2 * 10, width: 2 * 10, height: 10}]
          }
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # moving into view
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]], autoscroll: false)
          expectValues stateForSelection(presenter, 1), {
            regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # becoming empty
          expectStateUpdate presenter, -> editor.getSelections()[1].clear(autoscroll: false)
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # becoming non-empty
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]], autoscroll: false)
          expectValues stateForSelection(presenter, 1), {
            regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # moving out of view
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[3, 4], [3, 6]], autoscroll: false)
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # adding
          expectStateUpdate presenter, -> editor.addSelectionForBufferRange([[1, 4], [1, 6]], autoscroll: false)
          expectValues stateForSelection(presenter, 2), {
            regions: [{top: 1 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # moving added selection
          expectStateUpdate presenter, -> editor.getSelections()[2].setBufferRange([[1, 4], [1, 8]], autoscroll: false)
          expectValues stateForSelection(presenter, 2), {
            regions: [{top: 1 * 10, left: 4 * 10, width: 4 * 10, height: 10}]
          }

          # destroying
          destroyedSelection = editor.getSelections()[2]
          expectStateUpdate presenter, -> destroyedSelection.destroy()
          expect(stateForHighlight(presenter, destroyedSelection.decoration)).toBeUndefined()

        it "updates when highlight decorations' properties are updated", ->
          marker = editor.markBufferRange([[2, 2], [2, 4]])
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')

          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          expectValues stateForHighlight(presenter, highlight), {class: 'a'}
          expectStateUpdate presenter, -> highlight.setProperties(class: 'b', type: 'highlight')
          expectValues stateForHighlight(presenter, highlight), {class: 'b'}

        it "increments the .flashCount and sets the .flashClass and .flashDuration when the highlight model flashes", ->
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          marker = editor.markBufferRange([[2, 2], [2, 4]])
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')
          expectStateUpdate presenter, -> highlight.flash('b', 500)

          expectValues stateForHighlight(presenter, highlight), {
            flashClass: 'b'
            flashDuration: 500
            flashCount: 1
          }

          expectStateUpdate presenter, -> highlight.flash('c', 600)

          expectValues stateForHighlight(presenter, highlight), {
            flashClass: 'c'
            flashDuration: 600
            flashCount: 2
          }

      describe ".overlays", ->
        [item] = []
        stateForOverlay = (presenter, decoration) ->
          presenter.getState().content.overlays[decoration.id]

        it "contains state for overlay decorations both initially and when their markers move", ->
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = buildPresenter(explicitHeight: 30, scrollTop: 20)

          # Initial state
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
          }

          # Change range
          expectStateUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]])
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 5 * 10 - presenter.state.content.scrollTop, left: 6 * 10}
          }

          # Valid -> invalid
          expectStateUpdate presenter, -> editor.getBuffer().insert([2, 14], 'x')
          expect(stateForOverlay(presenter, decoration)).toBeUndefined()

          # Invalid -> valid
          expectStateUpdate presenter, -> editor.undo()
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 5 * 10 - presenter.state.content.scrollTop, left: 6 * 10}
          }

          # Reverse direction
          expectStateUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]], reversed: true)
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
          }

          # Destroy
          decoration.destroy()
          expect(stateForOverlay(presenter, decoration)).toBeUndefined()

          # Add
          decoration2 = editor.decorateMarker(marker, {type: 'overlay', item})
          expectValues stateForOverlay(presenter, decoration2), {
            item: item
            pixelPosition: {top: 3 * 10 - presenter.state.content.scrollTop, left: 13 * 10}
          }

        it "updates when ::baseCharacterWidth changes", ->
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

          presenter = buildPresenter(baseCharacterWidth: null, lineHeight: null, windowWidth: null, windowHeight: null, boundingClientRect: null)
          expect(presenter.getState().content.overlays).toEqual({})

          presenter.setBaseCharacterWidth(10)
          expect(presenter.getState().content.overlays).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.getState().content.overlays).toEqual({})

          presenter.setWindowSize(500, 100)
          expect(presenter.getState().content.overlays).toEqual({})

          presenter.setBoundingClientRect({top: 0, left: 0, height: 100, width: 500})
          expect(presenter.getState().content.overlays).not.toEqual({})

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

            presenter = buildPresenter({scrollLeft, windowWidth, windowHeight, contentFrameWidth, boundingClientRect})
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

            presenter = buildPresenter({scrollTop, windowWidth, windowHeight, contentFrameWidth, boundingClientRect})
            expectStateUpdate presenter, ->
              presenter.setOverlayDimensions(decoration.id, itemWidth, itemHeight, contentMargin)

            expectValues stateForOverlay(presenter, decoration), {
              item: item
              pixelPosition: {top: 6 * 10 - scrollTop, left: gutterWidth}
            }

            expectStateUpdate presenter, ->
              editor.insertNewline()
              editor.setScrollTop(scrollTop) # I'm fighting the editor
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

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect})
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

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect})
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

              presenter = buildPresenter({windowWidth, windowHeight, contentFrameWidth, boundingClientRect})
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


    describe ".gutter", ->
      describe ".scrollHeight", ->
        it "is initialized based on ::lineHeight, the number of lines, and ::explicitHeight", ->
          presenter = buildPresenter()
          expect(presenter.getState().gutter.scrollHeight).toBe editor.getScreenLineCount() * 10

          presenter = buildPresenter(explicitHeight: 500)
          expect(presenter.getState().gutter.scrollHeight).toBe 500

        it "updates when the ::lineHeight changes", ->
          presenter = buildPresenter()
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(presenter.getState().gutter.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = buildPresenter()
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(presenter.getState().gutter.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when ::explicitHeight changes", ->
          presenter = buildPresenter()
          expectStateUpdate presenter, -> presenter.setExplicitHeight(500)
          expect(presenter.getState().gutter.scrollHeight).toBe 500

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().gutter.scrollHeight).toBe presenter.contentHeight

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", true)
          expect(presenter.getState().gutter.scrollHeight).toBe presenter.contentHeight + presenter.clientHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().gutter.scrollHeight).toBe presenter.contentHeight

      describe ".scrollTop", ->
        it "tracks the value of ::scrollTop", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 20)
          expect(presenter.getState().gutter.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(presenter.getState().gutter.scrollTop).toBe 50

        it "never exceeds the computed scrollHeight minus the computed clientHeight", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(100)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setExplicitHeight(60)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> presenter.setHorizontalScrollbarHeight(5)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          expectStateUpdate presenter, -> editor.getBuffer().delete([[8, 0], [12, 0]])
          expect(presenter.getState().gutter.scrollTop).toBe presenter.scrollHeight - presenter.clientHeight

          # Scroll top only gets smaller when needed as dimensions change, never bigger
          scrollTopBefore = presenter.getState().verticalScrollbar.scrollTop
          expectStateUpdate presenter, -> editor.getBuffer().insert([9, Infinity], '\n\n\n')
          expect(presenter.getState().gutter.scrollTop).toBe scrollTopBefore

        it "never goes negative", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(-100)
          expect(presenter.getState().gutter.scrollTop).toBe 0

        it "adds the computed clientHeight to the computed scrollHeight if editor.scrollPastEnd is true", ->
          presenter = buildPresenter(scrollTop: 10, explicitHeight: 50, horizontalScrollbarHeight: 10)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

          atom.config.set("editor.scrollPastEnd", true)
          expectStateUpdate presenter, -> presenter.setScrollTop(300)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.contentHeight - (presenter.lineHeight * 3)

          expectStateUpdate presenter, -> atom.config.set("editor.scrollPastEnd", false)
          expect(presenter.getState().gutter.scrollTop).toBe presenter.contentHeight - presenter.clientHeight

      describe ".backgroundColor", ->
        it "is assigned to ::gutterBackgroundColor if present, and to ::backgroundColor otherwise", ->
          presenter = buildPresenter(backgroundColor: "rgba(255, 0, 0, 0)", gutterBackgroundColor: "rgba(0, 255, 0, 0)")
          expect(presenter.getState().gutter.backgroundColor).toBe "rgba(0, 255, 0, 0)"

          expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 255, 0)")
          expect(presenter.getState().gutter.backgroundColor).toBe "rgba(0, 0, 255, 0)"

          expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 0, 0)")
          expect(presenter.getState().gutter.backgroundColor).toBe "rgba(255, 0, 0, 0)"

          expectStateUpdate presenter, -> presenter.setBackgroundColor("rgba(0, 0, 255, 0)")
          expect(presenter.getState().gutter.backgroundColor).toBe "rgba(0, 0, 255, 0)"

      describe ".maxLineNumberDigits", ->
        it "is set to the number of digits used by the greatest line number", ->
          presenter = buildPresenter()
          expect(editor.getLastBufferRow()).toBe 12
          expect(presenter.getState().gutter.maxLineNumberDigits).toBe 2

          editor.setText("1\n2\n3")
          expect(presenter.getState().gutter.maxLineNumberDigits).toBe 1

      describe ".lineNumbers", ->
        lineNumberStateForScreenRow = (presenter, screenRow) ->
          editor = presenter.model
          bufferRow = editor.bufferRowForScreenRow(screenRow)
          wrapCount = screenRow - editor.screenRowForBufferRow(bufferRow)
          if wrapCount > 0
            key = bufferRow + '-' + wrapCount
          else
            key = bufferRow

          presenter.getState().gutter.lineNumbers[key]

        it "contains states for line numbers that are visible on screen, plus and minus the overdraw margin", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 30, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {screenRow: 2, bufferRow: 2, softWrapped: false, top: 2 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 3), {screenRow: 3, bufferRow: 3, softWrapped: false, top: 3 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 4), {screenRow: 4, bufferRow: 3, softWrapped: true, top: 4 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 4, softWrapped: false, top: 5 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 7, softWrapped: false, top: 6 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 8, softWrapped: false, top: 7 * 10}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

        it "includes states for all line numbers if no ::explicitHeight is assigned", ->
          presenter = buildPresenter(explicitHeight: null)
          expect(lineNumberStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 12)).toBeDefined()

        it "updates when ::scrollTop changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 30, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setScrollTop(20)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 1), {bufferRow: 1}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 7}
          expect(lineNumberStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::explicitHeight changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 30, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setExplicitHeight(35)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 8), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 9)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 0, lineOverdrawMargin: 0)

          expectValues lineNumberStateForScreenRow(presenter, 0), {bufferRow: 0}
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expect(lineNumberStateForScreenRow(presenter, 4)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues lineNumberStateForScreenRow(presenter, 0), {bufferRow: 0}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 4}
          expect(lineNumberStateForScreenRow(presenter, 6)).toBeUndefined()

        it "updates when the editor's content changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = buildPresenter(explicitHeight: 35, scrollTop: 30, lineOverdrawMargin: 0)

          expect(lineNumberStateForScreenRow(presenter, 2)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 4}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 7}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, ->
            editor.getBuffer().insert([3, Infinity], new Array(25).join("x "))

          expect(lineNumberStateForScreenRow(presenter, 2)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 4}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 7}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

        it "does not remove out-of-view line numbers corresponding to ::mouseWheelScreenRow until ::stoppedScrollingDelay elapses", ->
          presenter = buildPresenter(explicitHeight: 25, lineOverdrawMargin: 1, stoppedScrollingDelay: 200)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 5)).toBeUndefined()

          presenter.setMouseWheelScreenRow(0)
          expectStateUpdate presenter, -> presenter.setScrollTop(35)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineNumberStateForScreenRow(presenter, 7)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> advanceClock(200)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineNumberStateForScreenRow(presenter, 7)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

        it "correctly handles the first screen line being soft-wrapped", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(30)
          presenter = buildPresenter(explicitHeight: 25, scrollTop: 50)

          expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 3, softWrapped: true}
          expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 3, softWrapped: true}
          expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 4, softWrapped: false}

        describe ".decorationClasses", ->
          it "adds decoration classes to the relevant line number state objects, both initially and when decorations change", ->
            marker1 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
            decoration1 = editor.decorateMarker(marker1, type: 'line-number', class: 'a')
            presenter = buildPresenter()
            marker2 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
            decoration2 = editor.decorateMarker(marker2, type: 'line-number', class: 'b')

            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
            expect(marker1.isValid()).toBe false
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.undo()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> decoration1.destroy()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker2.destroy()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

          it "honors the 'onlyEmpty' option on line-number decorations", ->
            presenter = buildPresenter()
            marker = editor.markBufferRange([[4, 0], [6, 1]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyEmpty: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker.clearTail()

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

          it "honors the 'onlyNonEmpty' option on line-number decorations", ->
            presenter = buildPresenter()
            marker = editor.markBufferRange([[4, 0], [6, 2]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyNonEmpty: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            expectStateUpdate presenter, -> marker.clearTail()

            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

          it "honors the 'onlyHead' option on line-number decorations", ->
            presenter = buildPresenter()
            marker = editor.markBufferRange([[4, 0], [6, 2]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyHead: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

          it "does not decorate the last line of a non-empty line-number decoration range if it ends at column 0", ->
            presenter = buildPresenter()
            marker = editor.markBufferRange([[4, 0], [6, 0]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

          it "does not apply line-number decorations to mini editors", ->
            editor.setMini(true)
            presenter = buildPresenter()
            marker = editor.markBufferRange([[0, 0], [0, 0]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.setMini(false)
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'cursor-line-no-selection', 'a']

            expectStateUpdate presenter, -> editor.setMini(true)
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

          it "only applies line-number decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
            editor.setText("a line that wraps, ok")
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(16)
            marker = editor.markBufferRange([[0, 0], [0, 2]])
            editor.decorateMarker(marker, type: 'line-number', class: 'a')
            presenter = buildPresenter(explicitHeight: 10)

            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

            marker.setBufferRange([[0, 0], [0, Infinity]])
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

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

      describe ".visible", ->
        it "is true iff the editor isn't mini, ::isGutterVisible is true on the editor, and 'editor.showLineNumbers' is enabled in config", ->
          presenter = buildPresenter()

          expect(editor.isGutterVisible()).toBe true
          expect(presenter.getState().gutter.visible).toBe true

          expectStateUpdate presenter, -> editor.setMini(true)
          expect(presenter.getState().gutter.visible).toBe false

          expectStateUpdate presenter, -> editor.setMini(false)
          expect(presenter.getState().gutter.visible).toBe true

          expectStateUpdate presenter, -> editor.setGutterVisible(false)
          expect(presenter.getState().gutter.visible).toBe false

          expectStateUpdate presenter, -> editor.setGutterVisible(true)
          expect(presenter.getState().gutter.visible).toBe true

          expectStateUpdate presenter, -> atom.config.set('editor.showLineNumbers', false)
          expect(presenter.getState().gutter.visible).toBe false

        it "updates when the editor's grammar changes", ->
          presenter = buildPresenter()

          atom.config.set('editor.showLineNumbers', false, scopeSelector: '.source.js')
          expect(presenter.getState().gutter.visible).toBe true
          stateUpdated = false
          presenter.onDidUpdateState -> stateUpdated = true

          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            expect(stateUpdated).toBe true
            expect(presenter.getState().gutter.visible).toBe false

    describe ".height", ->
      it "tracks the computed content height if ::autoHeight is true so the editor auto-expands vertically", ->
        presenter = buildPresenter(explicitHeight: null, autoHeight: true)
        expect(presenter.getState().height).toBe editor.getScreenLineCount() * 10

        expectStateUpdate presenter, -> presenter.setAutoHeight(false)
        expect(presenter.getState().height).toBe null

        expectStateUpdate presenter, -> presenter.setAutoHeight(true)
        expect(presenter.getState().height).toBe editor.getScreenLineCount() * 10

        expectStateUpdate presenter, -> presenter.setLineHeight(20)
        expect(presenter.getState().height).toBe editor.getScreenLineCount() * 20

        expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
        expect(presenter.getState().height).toBe editor.getScreenLineCount() * 20

    describe ".focused", ->
      it "tracks the value of ::focused", ->
        presenter = buildPresenter(focused: false)
        expect(presenter.getState().focused).toBe false
        expectStateUpdate presenter, -> presenter.setFocused(true)
        expect(presenter.getState().focused).toBe true
        expectStateUpdate presenter, -> presenter.setFocused(false)
        expect(presenter.getState().focused).toBe false

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
      editor = new TextEditor({buffer})
      editor.setEditorWidthInChars(80)
      presenterParams =
        model: editor
        lineOverdrawMargin: 1
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
      actualState = presenter.getState()
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
