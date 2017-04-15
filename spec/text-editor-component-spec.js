const {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise, timeoutPromise} = require('./async-spec-helpers')

const TextEditorComponent = require('../src/text-editor-component')
const TextEditor = require('../src/text-editor')
const TextBuffer = require('text-buffer')
const fs = require('fs')
const path = require('path')

const SAMPLE_TEXT = fs.readFileSync(path.join(__dirname, 'fixtures', 'sample.js'), 'utf8')
const NBSP_CHARACTER = '\u00a0'

document.registerElement('text-editor-component-test-element', {
  prototype: Object.create(HTMLElement.prototype, {
    attachedCallback: {
      value: function () {
        this.didAttach()
      }
    }
  })
})

describe('TextEditorComponent', () => {
  beforeEach(() => {
    jasmine.useRealClock()
  })

  describe('rendering', () => {
    it('renders lines and line numbers for the visible region', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 3, autoHeight: false})

      expect(element.querySelectorAll('.line-number:not(.dummy)').length).toBe(13)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(13)

      element.style.height = 4 * component.measurements.lineHeight + 'px'
      await component.getNextUpdatePromise()
      expect(element.querySelectorAll('.line-number:not(.dummy)').length).toBe(9)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(9)

      await setScrollTop(component, 5 * component.getLineHeight())

      // After scrolling down beyond > 3 rows, the order of line numbers and lines
      // in the DOM is a bit weird because the first tile is recycled to the bottom
      // when it is scrolled out of view
      expect(Array.from(element.querySelectorAll('.line-number:not(.dummy)')).map(element => element.textContent.trim())).toEqual([
        '10', '11', '12', '4', '5', '6', '7', '8', '9'
      ])
      expect(Array.from(element.querySelectorAll('.line:not(.dummy)')).map(element => element.textContent)).toEqual([
        editor.lineTextForScreenRow(9),
        ' ', // this line is blank in the model, but we render a space to prevent the line from collapsing vertically
        editor.lineTextForScreenRow(11),
        editor.lineTextForScreenRow(3),
        editor.lineTextForScreenRow(4),
        editor.lineTextForScreenRow(5),
        editor.lineTextForScreenRow(6),
        editor.lineTextForScreenRow(7),
        editor.lineTextForScreenRow(8)
      ])

      await setScrollTop(component, 2.5 * component.getLineHeight())
      expect(Array.from(element.querySelectorAll('.line-number:not(.dummy)')).map(element => element.textContent.trim())).toEqual([
        '1', '2', '3', '4', '5', '6', '7', '8', '9'
      ])
      expect(Array.from(element.querySelectorAll('.line:not(.dummy)')).map(element => element.textContent)).toEqual([
        editor.lineTextForScreenRow(0),
        editor.lineTextForScreenRow(1),
        editor.lineTextForScreenRow(2),
        editor.lineTextForScreenRow(3),
        editor.lineTextForScreenRow(4),
        editor.lineTextForScreenRow(5),
        editor.lineTextForScreenRow(6),
        editor.lineTextForScreenRow(7),
        editor.lineTextForScreenRow(8)
      ])
    })

    it('bases the width of the lines div on the width of the longest initially-visible screen line', () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 2, height: 20})

      expect(editor.getApproximateLongestScreenRow()).toBe(3)
      const expectedWidth = element.querySelectorAll('.line')[3].offsetWidth
      expect(element.querySelector('.lines').style.width).toBe(expectedWidth + 'px')

      // TODO: Confirm that we'll update this value as indexing proceeds
    })

    it('honors the scrollPastEnd option by adding empty space equivalent to the clientHeight to the end of the content area', async () => {
      const {component, element, editor} = buildComponent({autoHeight: false, autoWidth: false})
      const {scrollContainer} = component.refs

      await editor.update({scrollPastEnd: true})
      await setEditorHeightInLines(component, 6)

      // scroll to end
      await setScrollTop(component, scrollContainer.scrollHeight - scrollContainer.clientHeight)
      expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() - 3)

      editor.update({scrollPastEnd: false})
      await component.getNextUpdatePromise() // wait for scrollable content resize
      expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() - 6)

      // Always allows at least 3 lines worth of overscroll if the editor is short
      await setEditorHeightInLines(component, 2)
      await editor.update({scrollPastEnd: true})
      await setScrollTop(component, scrollContainer.scrollHeight - scrollContainer.clientHeight)
      expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() + 1)
    })

    it('gives the line number tiles an explicit width and height so their layout can be strictly contained', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 3})

      const lineNumberGutterElement = component.refs.lineNumberGutter.element
      expect(lineNumberGutterElement.offsetHeight).toBe(component.getScrollHeight())

      for (const child of lineNumberGutterElement.children) {
        expect(child.offsetWidth).toBe(lineNumberGutterElement.offsetWidth)
      }

      editor.setText('\n'.repeat(99))
      await component.getNextUpdatePromise()
      expect(lineNumberGutterElement.offsetHeight).toBe(component.getScrollHeight())
      for (const child of lineNumberGutterElement.children) {
        expect(child.offsetWidth).toBe(lineNumberGutterElement.offsetWidth)
      }
    })

    it('renders dummy vertical and horizontal scrollbars when content overflows', async () => {
      const {component, element, editor} = buildComponent({height: 100, width: 100})
      const verticalScrollbar = component.refs.verticalScrollbar.element
      const horizontalScrollbar = component.refs.horizontalScrollbar.element
      expect(verticalScrollbar.scrollHeight).toBe(component.getContentHeight())
      expect(horizontalScrollbar.scrollWidth).toBe(component.getContentWidth())
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0)
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0)
      expect(verticalScrollbar.style.bottom).toBe(getVerticalScrollbarWidth(component) + 'px')
      expect(horizontalScrollbar.style.right).toBe(getHorizontalScrollbarHeight(component) + 'px')
      expect(component.refs.scrollbarCorner).toBeDefined()

      setScrollTop(component, 100)
      await setScrollLeft(component, 100)
      expect(verticalScrollbar.scrollTop).toBe(100)
      expect(horizontalScrollbar.scrollLeft).toBe(100)

      verticalScrollbar.scrollTop = 120
      horizontalScrollbar.scrollLeft = 120
      await component.getNextUpdatePromise()
      expect(component.getScrollTop()).toBe(120)
      expect(component.getScrollLeft()).toBe(120)

      editor.setText('a\n'.repeat(15))
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0)
      expect(getHorizontalScrollbarHeight(component)).toBe(0)
      expect(verticalScrollbar.style.bottom).toBe('0px')
      expect(component.refs.scrollbarCorner).toBeUndefined()

      editor.setText('a'.repeat(100))
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBe(0)
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0)
      expect(horizontalScrollbar.style.right).toBe('0px')
      expect(component.refs.scrollbarCorner).toBeUndefined()

      editor.setText('')
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBe(0)
      expect(getHorizontalScrollbarHeight(component)).toBe(0)
      expect(component.refs.scrollbarCorner).toBeUndefined()

      editor.setText(SAMPLE_TEXT)
      await component.getNextUpdatePromise()

      // Does not show scrollbars if the content perfectly fits
      element.style.width = component.getGutterContainerWidth() + component.getContentWidth() + 'px'
      element.style.height = component.getContentHeight() + 'px'
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBe(0)
      expect(getHorizontalScrollbarHeight(component)).toBe(0)

      // Shows scrollbars if the only reason we overflow is the presence of the
      // scrollbar for the opposite axis.
      element.style.width = component.getGutterContainerWidth() + component.getContentWidth() - 1 + 'px'
      element.style.height = component.getContentHeight() + component.getHorizontalScrollbarHeight() - 1 + 'px'
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0)
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0)

      element.style.width = component.getGutterContainerWidth() + component.getContentWidth() + component.getVerticalScrollbarWidth() - 1 + 'px'
      element.style.height = component.getContentHeight() - 1 + 'px'
      await component.getNextUpdatePromise()
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0)
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0)

    })

    it('updates the bottom/right of dummy scrollbars and client height/width measurements when scrollbar styles change', async () => {
      const {component, element, editor} = buildComponent({height: 100, width: 100})
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(10)
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(10)

      const style = document.createElement('style')
      style.textContent = '::-webkit-scrollbar { height: 10px; width: 10px; }'
      jasmine.attachToDOM(style)

      TextEditor.didUpdateScrollbarStyles()
      await component.getNextUpdatePromise()

      expect(getHorizontalScrollbarHeight(component)).toBe(10)
      expect(getVerticalScrollbarWidth(component)).toBe(10)
      expect(component.refs.horizontalScrollbar.element.style.right).toBe('10px')
      expect(component.refs.verticalScrollbar.element.style.bottom).toBe('10px')
      expect(component.getScrollContainerClientHeight()).toBe(100 - 10)
      expect(component.getScrollContainerClientWidth()).toBe(100 - component.getGutterContainerWidth() - 10)
    })

    it('renders cursors within the visible row range', async () => {
      const {component, element, editor} = buildComponent({height: 40, rowsPerTile: 2})
      await setScrollTop(component, 100)

      expect(component.getRenderedStartRow()).toBe(4)
      expect(component.getRenderedEndRow()).toBe(10)

      editor.setCursorScreenPosition([0, 0], {autoscroll: false}) // out of view
      editor.addCursorAtScreenPosition([2, 2], {autoscroll: false}) // out of view
      editor.addCursorAtScreenPosition([4, 0], {autoscroll: false}) // line start
      editor.addCursorAtScreenPosition([4, 4], {autoscroll: false}) // at token boundary
      editor.addCursorAtScreenPosition([4, 6], {autoscroll: false}) // within token
      editor.addCursorAtScreenPosition([5, Infinity], {autoscroll: false}) // line end
      editor.addCursorAtScreenPosition([10, 2], {autoscroll: false}) // out of view
      await component.getNextUpdatePromise()

      let cursorNodes = Array.from(element.querySelectorAll('.cursor'))
      expect(cursorNodes.length).toBe(4)
      verifyCursorPosition(component, cursorNodes[0], 4, 0)
      verifyCursorPosition(component, cursorNodes[1], 4, 4)
      verifyCursorPosition(component, cursorNodes[2], 4, 6)
      verifyCursorPosition(component, cursorNodes[3], 5, 30)

      editor.setCursorScreenPosition([8, 11], {autoscroll: false})
      await component.getNextUpdatePromise()

      cursorNodes = Array.from(element.querySelectorAll('.cursor'))
      expect(cursorNodes.length).toBe(1)
      verifyCursorPosition(component, cursorNodes[0], 8, 11)

      editor.setCursorScreenPosition([0, 0], {autoscroll: false})
      await component.getNextUpdatePromise()

      cursorNodes = Array.from(element.querySelectorAll('.cursor'))
      expect(cursorNodes.length).toBe(0)

      editor.setSelectedScreenRange([[8, 0], [12, 0]], {autoscroll: false})
      await component.getNextUpdatePromise()
      cursorNodes = Array.from(element.querySelectorAll('.cursor'))
      expect(cursorNodes.length).toBe(0)
    })

    it('hides cursors with non-empty selections when showCursorOnSelection is false', async () => {
      const {component, element, editor} = buildComponent()
      editor.setSelectedScreenRanges([
        [[0, 0], [0, 3]],
        [[1, 0], [1, 0]]
      ])
      await component.getNextUpdatePromise()
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'))
        expect(cursorNodes.length).toBe(2)
        verifyCursorPosition(component, cursorNodes[0], 0, 3)
        verifyCursorPosition(component, cursorNodes[1], 1, 0)
      }

      editor.update({showCursorOnSelection: false})
      await component.getNextUpdatePromise()
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'))
        expect(cursorNodes.length).toBe(1)
        verifyCursorPosition(component, cursorNodes[0], 1, 0)
      }

      editor.setSelectedScreenRanges([
        [[0, 0], [0, 3]],
        [[1, 0], [1, 4]]
      ])
      await component.getNextUpdatePromise()
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'))
        expect(cursorNodes.length).toBe(0)
      }
    })

    it('blinks cursors when the editor is focused and the cursors are not moving', async () => {
      assertDocumentFocused()
      const {component, element, editor} = buildComponent()
      component.props.cursorBlinkPeriod = 40
      component.props.cursorBlinkResumeDelay = 40
      editor.addCursorAtScreenPosition([1, 0])

      element.focus()
      await component.getNextUpdatePromise()
      const [cursor1, cursor2] = element.querySelectorAll('.cursor')

      expect(getComputedStyle(cursor1).opacity).toBe('1')
      expect(getComputedStyle(cursor2).opacity).toBe('1')

      await conditionPromise(() =>
        getComputedStyle(cursor1).opacity === '0' && getComputedStyle(cursor2).opacity === '0'
      )

      await conditionPromise(() =>
        getComputedStyle(cursor1).opacity === '1' && getComputedStyle(cursor2).opacity === '1'
      )

      await conditionPromise(() =>
        getComputedStyle(cursor1).opacity === '0' && getComputedStyle(cursor2).opacity === '0'
      )

      editor.moveRight()
      await component.getNextUpdatePromise()

      expect(getComputedStyle(cursor1).opacity).toBe('1')
      expect(getComputedStyle(cursor2).opacity).toBe('1')
    })

    it('gives cursors at the end of lines the width of an "x" character', async () => {
      const {component, element, editor} = buildComponent()
      editor.setCursorScreenPosition([0, Infinity])
      await component.getNextUpdatePromise()
      expect(element.querySelector('.cursor').offsetWidth).toBe(Math.round(component.getBaseCharacterWidth()))
    })

    it('places the hidden input element at the location of the last cursor if it is visible', async () => {
      const {component, element, editor} = buildComponent({height: 60, width: 120, rowsPerTile: 2})
      const {hiddenInput} = component.refs
      setScrollTop(component, 100)
      await setScrollLeft(component, 40)

      expect(component.getRenderedStartRow()).toBe(4)
      expect(component.getRenderedEndRow()).toBe(10)

      // When out of view, the hidden input is positioned at 0, 0
      expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      expect(hiddenInput.offsetTop).toBe(0)
      expect(hiddenInput.offsetLeft).toBe(0)

      // Otherwise it is positioned at the last cursor position
      editor.addCursorAtScreenPosition([7, 4])
      await component.getNextUpdatePromise()
      expect(hiddenInput.getBoundingClientRect().top).toBe(clientTopForLine(component, 7))
      expect(Math.round(hiddenInput.getBoundingClientRect().left)).toBe(clientLeftForCharacter(component, 7, 4))
    })

    it('soft wraps lines based on the content width when soft wrap is enabled', async () => {
      const {component, element, editor} = buildComponent({width: 435, attach: false})
      editor.setSoftWrapped(true)
      jasmine.attachToDOM(element)

      expect(getEditorWidthInBaseCharacters(component)).toBe(55)
      expect(lineNodeForScreenRow(component, 3).textContent).toBe(
        '    var pivot = items.shift(), current, left = [], '
      )
      expect(lineNodeForScreenRow(component, 4).textContent).toBe(
        '    right = [];'
      )

      await setEditorWidthInCharacters(component, 45)
      expect(lineNodeForScreenRow(component, 3).textContent).toBe(
        '    var pivot = items.shift(), current, left '
      )
      expect(lineNodeForScreenRow(component, 4).textContent).toBe(
        '    = [], right = [];'
      )

      const {scrollContainer} = component.refs
      expect(scrollContainer.clientWidth).toBe(scrollContainer.scrollWidth)
    })

    it('decorates the line numbers of folded lines', async () => {
      const {component, element, editor} = buildComponent()
      editor.foldBufferRow(1)
      await component.getNextUpdatePromise()
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('folded')).toBe(true)
    })

    it('makes lines at least as wide as the scrollContainer', async () => {
      const {component, element, editor} = buildComponent()
      const {scrollContainer, gutterContainer} = component.refs
      editor.setText('a')
      await component.getNextUpdatePromise()

      expect(element.querySelector('.line').offsetWidth).toBe(scrollContainer.offsetWidth)
    })

    it('resizes based on the content when the autoHeight and/or autoWidth options are true', async () => {
      const {component, element, editor} = buildComponent({autoHeight: true, autoWidth: true})
      const editorPadding = 3
      element.style.padding = editorPadding + 'px'
      const {gutterContainer, scrollContainer} = component.refs
      const initialWidth = element.offsetWidth
      const initialHeight = element.offsetHeight
      expect(initialWidth).toBe(component.getGutterContainerWidth() + component.getContentWidth() + 2 * editorPadding)
      expect(initialHeight).toBe(component.getContentHeight() + 2 * editorPadding)

      // When autoWidth is enabled, width adjusts to content
      editor.setCursorScreenPosition([6, Infinity])
      editor.insertText('x'.repeat(50))
      await component.getNextUpdatePromise()
      expect(element.offsetWidth).toBe(component.getGutterContainerWidth() + component.getContentWidth() + 2 * editorPadding)
      expect(element.offsetWidth).toBeGreaterThan(initialWidth)

      // When autoHeight is enabled, height adjusts to content
      editor.insertText('\n'.repeat(5))
      await component.getNextUpdatePromise()
      expect(element.offsetHeight).toBe(component.getContentHeight() + 2 * editorPadding)
      expect(element.offsetHeight).toBeGreaterThan(initialHeight)

      // When a horizontal scrollbar is visible, autoHeight accounts for it
      editor.update({autoWidth: false})
      await component.getNextUpdatePromise()
      element.style.width = component.getGutterContainerWidth() + component.getContentHeight() - 20 + 'px'
      await component.getNextUpdatePromise()
      expect(component.isHorizontalScrollbarVisible()).toBe(true)
      expect(component.isVerticalScrollbarVisible()).toBe(false)
      expect(element.offsetHeight).toBe(component.getContentHeight() + component.getHorizontalScrollbarHeight() + 2 * editorPadding)

      // When a vertical scrollbar is visible, autoWidth accounts for it
      editor.update({autoWidth: true, autoHeight: false})
      await component.getNextUpdatePromise()
      element.style.height = component.getContentHeight() - 20
      await component.getNextUpdatePromise()
      expect(component.isHorizontalScrollbarVisible()).toBe(false)
      expect(component.isVerticalScrollbarVisible()).toBe(true)
      expect(element.offsetWidth).toBe(
        component.getGutterContainerWidth() +
        component.getContentWidth() +
        component.getVerticalScrollbarWidth() +
        2 * editorPadding
      )
    })

    it('supports the isLineNumberGutterVisible parameter', () => {
      const {component, element, editor} = buildComponent({lineNumberGutterVisible: false})
      expect(element.querySelector('.line-number')).toBe(null)
    })

    it('supports the placeholderText parameter', () => {
      const placeholderText = 'Placeholder Test'
      const {element} = buildComponent({placeholderText, text: ''})
      expect(element.textContent).toContain(placeholderText)
    })

    it('adds the data-grammar attribute and updates it when the grammar changes', async () => {
      await atom.packages.activatePackage('language-javascript')

      const {editor, element, component} = buildComponent()
      expect(element.dataset.grammar).toBe('text plain null-grammar')

      editor.setGrammar(atom.grammars.grammarForScopeName('source.js'))
      await component.getNextUpdatePromise()
      expect(element.dataset.grammar).toBe('source js')
    })

    it('adds the data-encoding attribute and updates it when the encoding changes', async () => {
      const {editor, element, component} = buildComponent()
      expect(element.dataset.encoding).toBe('utf8')

      editor.setEncoding('ascii')
      await component.getNextUpdatePromise()
      expect(element.dataset.encoding).toBe('ascii')
    })

    it('adds the has-selection class when the editor has a non-empty selection', async () => {
      const {editor, element, component} = buildComponent()
      expect(element.classList.contains('has-selection')).toBe(false)

      editor.setSelectedBufferRanges([
        [[0, 0], [0, 0]],
        [[1, 0], [1, 10]]
      ])
      await component.getNextUpdatePromise()
      expect(element.classList.contains('has-selection')).toBe(true)

      editor.setSelectedBufferRanges([
        [[0, 0], [0, 0]],
        [[1, 0], [1, 0]]
      ])
      await component.getNextUpdatePromise()
      expect(element.classList.contains('has-selection')).toBe(false)
    })
  })

  describe('mini editors', () => {
    it('adds the mini attribute', () => {
      const {element, editor} = buildComponent({mini: true})
      expect(element.hasAttribute('mini')).toBe(true)
    })

    it('does not render the gutter container', () => {
      const {component, element, editor} = buildComponent({mini: true})
      expect(component.refs.gutterContainer).toBeUndefined()
      expect(element.querySelector('gutter-container')).toBeNull()
    })

    it('does not render line decorations for the cursor line', async () => {
      const {component, element, editor} = buildComponent({mini: true})
      expect(element.querySelector('.line').classList.contains('cursor-line')).toBe(false)

      editor.update({mini: false})
      await component.getNextUpdatePromise()
      expect(element.querySelector('.line').classList.contains('cursor-line')).toBe(true)

      editor.update({mini: true})
      await component.getNextUpdatePromise()
      expect(element.querySelector('.line').classList.contains('cursor-line')).toBe(false)
    })

    it('does not render scrollbars', async () => {
      const {component, element, editor} = buildComponent({mini: true, autoHeight: false})
      await setEditorWidthInCharacters(component, 10)
      await setEditorHeightInLines(component, 1)

      editor.setText('x'.repeat(20) + 'y'.repeat(20))
      await component.getNextUpdatePromise()

      expect(component.isHorizontalScrollbarVisible()).toBe(false)
      expect(component.isVerticalScrollbarVisible()).toBe(false)
      expect(component.refs.horizontalScrollbar).toBeUndefined()
      expect(component.refs.verticalScrollbar).toBeUndefined()
    })
  })

  describe('focus', () => {
    beforeEach(() => {
      assertDocumentFocused()
    })

    it('focuses the hidden input element and adds the is-focused class when focused', async () => {
      const {component, element, editor} = buildComponent()
      const {hiddenInput} = component.refs

      expect(document.activeElement).not.toBe(hiddenInput)
      element.focus()
      expect(document.activeElement).toBe(hiddenInput)
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(true)

      element.focus() // focusing back to the element does not blur
      expect(document.activeElement).toBe(hiddenInput)
      expect(element.classList.contains('is-focused')).toBe(true)

      document.body.focus()
      expect(document.activeElement).not.toBe(hiddenInput)
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(false)
    })

    it('updates the component when the hidden input is focused directly', async () => {
      const {component, element, editor} = buildComponent()
      const {hiddenInput} = component.refs
      expect(element.classList.contains('is-focused')).toBe(false)
      expect(document.activeElement).not.toBe(hiddenInput)

      hiddenInput.focus()
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(true)
    })

    it('gracefully handles a focus event that occurs prior to the attachedCallback of the element', () => {
      const {component, element, editor} = buildComponent({attach: false})
      const parent = document.createElement('text-editor-component-test-element')
      parent.appendChild(element)
      parent.didAttach = () => element.focus()
      jasmine.attachToDOM(parent)
      expect(document.activeElement).toBe(component.refs.hiddenInput)
    })

    it('gracefully handles a focus event that occurs prior to detecting the element has become visible', async () => {
      const {component, element, editor} = buildComponent({attach: false})
      element.style.display = 'none'
      jasmine.attachToDOM(element)
      element.style.display = 'block'
      element.focus()
      await component.getNextUpdatePromise()

      expect(document.activeElement).toBe(component.refs.hiddenInput)
    })

    it('emits blur events only when focus shifts to something other than the editor itself or its hidden input', () => {
      const {element} = buildComponent()

      let blurEventCount = 0
      element.addEventListener('blur', () => blurEventCount++)

      element.focus()
      expect(blurEventCount).toBe(0)
      element.focus()
      expect(blurEventCount).toBe(0)
      document.body.focus()
      expect(blurEventCount).toBe(1)
    })
  })

  describe('autoscroll', () => {
    it('automatically scrolls vertically when the requested range is within the vertical scroll margin of the top or bottom', async () => {
      const {component, editor} = buildComponent({height: 120})
      expect(component.getLastVisibleRow()).toBe(7)

      editor.scrollToScreenRange([[4, 0], [6, 0]])
      await component.getNextUpdatePromise()
      expect(component.getScrollBottom()).toBe((6 + 1 + editor.verticalScrollMargin) * component.getLineHeight())

      editor.scrollToScreenPosition([8, 0])
      await component.getNextUpdatePromise()
      expect(component.getScrollBottom()).toBe((8 + 1 + editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([3, 0])
      await component.getNextUpdatePromise()
      expect(component.getScrollTop()).toBe((3 - editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([2, 0])
      await component.getNextUpdatePromise()
      expect(component.getScrollTop()).toBe(0)
    })

    it('does not vertically autoscroll by more than half of the visible lines if the editor is shorter than twice the scroll margin', async () => {
      const {component, element, editor} = buildComponent({autoHeight: false})
      element.style.height = 5.5 * component.measurements.lineHeight + 'px'
      await component.getNextUpdatePromise()
      expect(component.getLastVisibleRow()).toBe(5)
      const scrollMarginInLines = 2

      editor.scrollToScreenPosition([6, 0])
      await component.getNextUpdatePromise()
      expect(component.getScrollBottom()).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([6, 4])
      await component.getNextUpdatePromise()
      expect(component.getScrollBottom()).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenRange([[4, 4], [6, 4]])
      await component.getNextUpdatePromise()
      expect(component.getScrollTop()).toBe((4 - scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenRange([[4, 4], [6, 4]], {reversed: false})
      await component.getNextUpdatePromise()
      expect(component.getScrollBottom()).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)
    })

    it('autoscrolls the given range to the center of the screen if the `center` option is true', async () => {
      const {component, editor} = buildComponent({height: 50})
      expect(component.getLastVisibleRow()).toBe(2)

      editor.scrollToScreenRange([[4, 0], [6, 0]], {center: true})
      await component.getNextUpdatePromise()

      const actualScrollCenter = (component.getScrollTop() + component.getScrollBottom()) / 2
      const expectedScrollCenter = Math.round((4 + 7) / 2 * component.getLineHeight())
      expect(actualScrollCenter).toBe(expectedScrollCenter)
    })

    it('automatically scrolls horizontally when the requested range is within the horizontal scroll margin of the right edge of the gutter or right edge of the scroll container', async () => {
      const {component, element, editor} = buildComponent()
      const {scrollContainer} = component.refs
      element.style.width =
        component.getGutterContainerWidth() +
        3 * editor.horizontalScrollMargin * component.measurements.baseCharacterWidth + 'px'
      await component.getNextUpdatePromise()

      editor.scrollToScreenRange([[1, 12], [2, 28]])
      await component.getNextUpdatePromise()
      let expectedScrollLeft = Math.round(
        clientLeftForCharacter(component, 1, 12) -
        lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
        (editor.horizontalScrollMargin * component.measurements.baseCharacterWidth)
      )
      expect(component.getScrollLeft()).toBe(expectedScrollLeft)

      editor.scrollToScreenRange([[1, 12], [2, 28]], {reversed: false})
      await component.getNextUpdatePromise()
      expectedScrollLeft = Math.round(
        component.getGutterContainerWidth() +
        clientLeftForCharacter(component, 2, 28) -
        lineNodeForScreenRow(component, 2).getBoundingClientRect().left +
        (editor.horizontalScrollMargin * component.measurements.baseCharacterWidth) -
        component.getScrollContainerClientWidth()
      )
      expect(component.getScrollLeft()).toBe(expectedScrollLeft)
    })

    it('does not horizontally autoscroll by more than half of the visible "base-width" characters if the editor is narrower than twice the scroll margin', async () => {
      const {component, editor} = buildComponent({autoHeight: false})
      await setEditorWidthInCharacters(component, 1.5 * editor.horizontalScrollMargin)

      const contentWidthInCharacters = Math.floor(component.getScrollContainerClientWidth() / component.getBaseCharacterWidth())
      expect(contentWidthInCharacters).toBe(9)

      editor.scrollToScreenRange([[6, 10], [6, 15]])
      await component.getNextUpdatePromise()
      let expectedScrollLeft = Math.floor(
        clientLeftForCharacter(component, 6, 10) -
        lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
        (4 * component.getBaseCharacterWidth())
      )
      expect(component.getScrollLeft()).toBe(expectedScrollLeft)
    })

    it('correctly autoscrolls after inserting a line that exceeds the current content width', async () => {
      const {component, element, editor} = buildComponent()
      element.style.width = component.getGutterContainerWidth() + component.getContentWidth() + 'px'
      await component.getNextUpdatePromise()

      editor.setCursorScreenPosition([0, Infinity])
      editor.insertText('x'.repeat(100))
      await component.getNextUpdatePromise()

      expect(component.getScrollLeft()).toBe(component.getScrollWidth() - component.getScrollContainerClientWidth())
    })

    it('accounts for the presence of horizontal scrollbars that appear during the same frame as the autoscroll', async () => {
      const {component, element, editor} = buildComponent()
      const {scrollContainer} = component.refs
      element.style.height = component.getScrollHeight() + 'px'
      element.style.width = component.getScrollWidth() + 'px'
      await component.getNextUpdatePromise()

      editor.setCursorScreenPosition([10, Infinity])
      editor.insertText('\n\n' + 'x'.repeat(100))
      await component.getNextUpdatePromise()

      expect(component.getScrollTop()).toBe(component.getScrollHeight() - component.getScrollContainerClientHeight())
      expect(component.getScrollLeft()).toBe(component.getScrollWidth() - component.getScrollContainerClientWidth())
    })
  })

  describe('line and line number decorations', () => {
    it('adds decoration classes on screen lines spanned by decorated markers', async () => {
      const {component, element, editor} = buildComponent({width: 435, attach: false})
      editor.setSoftWrapped(true)
      jasmine.attachToDOM(element)

      expect(lineNodeForScreenRow(component, 3).textContent).toBe(
        '    var pivot = items.shift(), current, left = [], '
      )
      expect(lineNodeForScreenRow(component, 4).textContent).toBe(
        '    right = [];'
      )

      const marker1 = editor.markScreenRange([[1, 10], [3, 10]])
      const layer = editor.addMarkerLayer()
      const marker2 = layer.markScreenPosition([5, 0])
      const marker3 = layer.markScreenPosition([8, 0])
      const marker4 = layer.markScreenPosition([10, 0])
      const markerDecoration = editor.decorateMarker(marker1, {type: ['line', 'line-number'], class: 'a'})
      const layerDecoration = editor.decorateMarkerLayer(layer, {type: ['line', 'line-number'], class: 'b'})
      layerDecoration.setPropertiesForMarker(marker4, {type: 'line', class: 'c'})
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 4).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 5).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 8).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 10).classList.contains('b')).toBe(false)
      expect(lineNodeForScreenRow(component, 10).classList.contains('c')).toBe(true)

      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 2).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 3).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 4).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 5).classList.contains('b')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 8).classList.contains('b')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 10).classList.contains('b')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 10).classList.contains('c')).toBe(false)

      marker1.setScreenRange([[5, 0], [8, 0]])
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 4).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 5).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 5).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 6).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 7).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 8).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 8).classList.contains('b')).toBe(true)

      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 2).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 3).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 4).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 5).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 5).classList.contains('b')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 6).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 7).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 8).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 8).classList.contains('b')).toBe(true)
    })

    it('honors the onlyEmpty and onlyNonEmpty decoration options', async () => {
      const {component, element, editor} = buildComponent()
      const marker = editor.markScreenPosition([1, 0])
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'a', onlyEmpty: true})
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'b', onlyNonEmpty: true})
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'c'})
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(false)
      expect(lineNodeForScreenRow(component, 1).classList.contains('c')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('b')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('c')).toBe(true)

      marker.setScreenRange([[1, 0], [2, 4]])
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 1).classList.contains('c')).toBe(true)
      expect(lineNodeForScreenRow(component, 2).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 2).classList.contains('c')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('b')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('c')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 2).classList.contains('b')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 2).classList.contains('c')).toBe(true)
    })

    it('honors the onlyHead option', async () => {
      const {component, element, editor} = buildComponent()
      const marker = editor.markScreenRange([[1, 4], [3, 4]])
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'a', onlyHead: true})
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(true)
      expect(lineNumberNodeForScreenRow(component, 1).classList.contains('a')).toBe(false)
      expect(lineNumberNodeForScreenRow(component, 3).classList.contains('a')).toBe(true)
    })

    it('only decorates the last row of non-empty ranges that end at column 0 if omitEmptyLastRow is false', async () => {
      const {component, element, editor} = buildComponent()
      const marker = editor.markScreenRange([[1, 0], [3, 0]])
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'a'})
      editor.decorateMarker(marker, {type: ['line', 'line-number'], class: 'b', omitEmptyLastRow: false})
      await component.getNextUpdatePromise()

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(true)
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(false)

      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 2).classList.contains('b')).toBe(true)
      expect(lineNodeForScreenRow(component, 3).classList.contains('b')).toBe(true)
    })
  })

  describe('highlight decorations', () => {
    it('renders single-line highlights', async () => {
      const {component, element, editor} = buildComponent()
      const marker = editor.markScreenRange([[1, 2], [1, 10]])
      editor.decorateMarker(marker, {type: 'highlight', class: 'a'})
      await component.getNextUpdatePromise()

      {
        const regions = element.querySelectorAll('.highlight.a .region')
        expect(regions.length).toBe(1)
        const regionRect = regions[0].getBoundingClientRect()
        expect(regionRect.top).toBe(lineNodeForScreenRow(component, 1).getBoundingClientRect().top)
        expect(Math.round(regionRect.left)).toBe(clientLeftForCharacter(component, 1, 2))
        expect(Math.round(regionRect.right)).toBe(clientLeftForCharacter(component, 1, 10))
      }

      marker.setScreenRange([[1, 4], [1, 8]])
      await component.getNextUpdatePromise()

      {
        const regions = element.querySelectorAll('.highlight.a .region')
        expect(regions.length).toBe(1)
        const regionRect = regions[0].getBoundingClientRect()
        expect(regionRect.top).toBe(lineNodeForScreenRow(component, 1).getBoundingClientRect().top)
        expect(regionRect.bottom).toBe(lineNodeForScreenRow(component, 1).getBoundingClientRect().bottom)
        expect(Math.round(regionRect.left)).toBe(clientLeftForCharacter(component, 1, 4))
        expect(Math.round(regionRect.right)).toBe(clientLeftForCharacter(component, 1, 8))
      }
    })

    it('renders multi-line highlights that span across tiles', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 3})
      const marker = editor.markScreenRange([[2, 4], [3, 4]])
      editor.decorateMarker(marker, {type: 'highlight', class: 'a'})

      await component.getNextUpdatePromise()

      {
        // We have 2 top-level highlight divs due to the regions being split
        // across 2 different tiles
        expect(element.querySelectorAll('.highlight.a').length).toBe(2)

        const regions = element.querySelectorAll('.highlight.a .region')
        expect(regions.length).toBe(2)
        const region0Rect = regions[0].getBoundingClientRect()
        expect(region0Rect.top).toBe(lineNodeForScreenRow(component, 2).getBoundingClientRect().top)
        expect(region0Rect.bottom).toBe(lineNodeForScreenRow(component, 2).getBoundingClientRect().bottom)
        expect(Math.round(region0Rect.left)).toBe(clientLeftForCharacter(component, 2, 4))
        expect(Math.round(region0Rect.right)).toBe(component.refs.content.getBoundingClientRect().right)

        const region1Rect = regions[1].getBoundingClientRect()
        expect(region1Rect.top).toBe(lineNodeForScreenRow(component, 3).getBoundingClientRect().top)
        expect(region1Rect.bottom).toBe(lineNodeForScreenRow(component, 3).getBoundingClientRect().bottom)
        expect(Math.round(region1Rect.left)).toBe(clientLeftForCharacter(component, 3, 0))
        expect(Math.round(region1Rect.right)).toBe(clientLeftForCharacter(component, 3, 4))
      }

      marker.setScreenRange([[2, 4], [5, 4]])
      await component.getNextUpdatePromise()

      {
        // Still split across 2 tiles
        expect(element.querySelectorAll('.highlight.a').length).toBe(2)

        const regions = element.querySelectorAll('.highlight.a .region')
        expect(regions.length).toBe(4) // Each tile renders its

        const region0Rect = regions[0].getBoundingClientRect()
        expect(region0Rect.top).toBe(lineNodeForScreenRow(component, 2).getBoundingClientRect().top)
        expect(region0Rect.bottom).toBe(lineNodeForScreenRow(component, 2).getBoundingClientRect().bottom)
        expect(Math.round(region0Rect.left)).toBe(clientLeftForCharacter(component, 2, 4))
        expect(Math.round(region0Rect.right)).toBe(component.refs.content.getBoundingClientRect().right)

        const region1Rect = regions[1].getBoundingClientRect()
        expect(region1Rect.top).toBe(lineNodeForScreenRow(component, 3).getBoundingClientRect().top)
        expect(region1Rect.bottom).toBe(lineNodeForScreenRow(component, 4).getBoundingClientRect().top)
        expect(Math.round(region1Rect.left)).toBe(component.refs.content.getBoundingClientRect().left)
        expect(Math.round(region1Rect.right)).toBe(component.refs.content.getBoundingClientRect().right)

        const region2Rect = regions[2].getBoundingClientRect()
        expect(region2Rect.top).toBe(lineNodeForScreenRow(component, 4).getBoundingClientRect().top)
        expect(region2Rect.bottom).toBe(lineNodeForScreenRow(component, 5).getBoundingClientRect().top)
        expect(Math.round(region2Rect.left)).toBe(component.refs.content.getBoundingClientRect().left)
        expect(Math.round(region2Rect.right)).toBe(component.refs.content.getBoundingClientRect().right)

        const region3Rect = regions[3].getBoundingClientRect()
        expect(region3Rect.top).toBe(lineNodeForScreenRow(component, 5).getBoundingClientRect().top)
        expect(region3Rect.bottom).toBe(lineNodeForScreenRow(component, 5).getBoundingClientRect().bottom)
        expect(Math.round(region3Rect.left)).toBe(component.refs.content.getBoundingClientRect().left)
        expect(Math.round(region3Rect.right)).toBe(clientLeftForCharacter(component, 5, 4))
      }
    })

    it('can flash highlight decorations', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 3, height: 200})
      const marker = editor.markScreenRange([[2, 4], [3, 4]])
      const decoration = editor.decorateMarker(marker, {type: 'highlight', class: 'a'})
      decoration.flash('b', 10)

      // Flash on initial appearence of highlight
      await component.getNextUpdatePromise()
      const highlights = element.querySelectorAll('.highlight.a')
      expect(highlights.length).toBe(2) // split across 2 tiles

      expect(highlights[0].classList.contains('b')).toBe(true)
      expect(highlights[1].classList.contains('b')).toBe(true)

      await conditionPromise(() =>
        !highlights[0].classList.contains('b') &&
        !highlights[1].classList.contains('b')
      )

      // Don't flash on next update if another flash wasn't requested
      await setScrollTop(component, 100)
      expect(highlights[0].classList.contains('b')).toBe(false)
      expect(highlights[1].classList.contains('b')).toBe(false)

      // Flash existing highlight
      decoration.flash('c', 100)
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('c')).toBe(true)
      expect(highlights[1].classList.contains('c')).toBe(true)

      // Add second flash class
      decoration.flash('d', 100)
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('c')).toBe(true)
      expect(highlights[1].classList.contains('c')).toBe(true)
      expect(highlights[0].classList.contains('d')).toBe(true)
      expect(highlights[1].classList.contains('d')).toBe(true)

      await conditionPromise(() =>
        !highlights[0].classList.contains('c') &&
        !highlights[1].classList.contains('c') &&
        !highlights[0].classList.contains('d') &&
        !highlights[1].classList.contains('d')
      )

      // Flashing the same class again before the first flash completes
      // removes the flash class and adds it back on the next frame to ensure
      // CSS transitions apply to the second flash.
      decoration.flash('e', 100)
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('e')).toBe(true)
      expect(highlights[1].classList.contains('e')).toBe(true)

      decoration.flash('e', 100)
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('e')).toBe(false)
      expect(highlights[1].classList.contains('e')).toBe(false)

      await conditionPromise(() =>
        highlights[0].classList.contains('e') &&
        highlights[1].classList.contains('e')
      )

      await conditionPromise(() =>
        !highlights[0].classList.contains('e') &&
        !highlights[1].classList.contains('e')
      )
    })

    it('supports layer decorations', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 12})
      const markerLayer = editor.addMarkerLayer()
      const marker1 = markerLayer.markScreenRange([[2, 4], [3, 4]])
      const marker2 = markerLayer.markScreenRange([[5, 6], [7, 8]])
      const decoration = editor.decorateMarkerLayer(markerLayer, {type: 'highlight', class: 'a'})
      await component.getNextUpdatePromise()

      const highlights = element.querySelectorAll('.highlight')
      expect(highlights[0].classList.contains('a')).toBe(true)
      expect(highlights[1].classList.contains('a')).toBe(true)

      decoration.setPropertiesForMarker(marker1, {type: 'highlight', class: 'b'})
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('b')).toBe(true)
      expect(highlights[1].classList.contains('a')).toBe(true)

      decoration.setPropertiesForMarker(marker1, null)
      decoration.setPropertiesForMarker(marker2, {type: 'highlight', class: 'c'})
      await component.getNextUpdatePromise()
      expect(highlights[0].classList.contains('a')).toBe(true)
      expect(highlights[1].classList.contains('c')).toBe(true)
    })

    it('clears highlights when recycling a tile that previously contained highlights and now does not', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 2, autoHeight: false})
      await setEditorHeightInLines(component, 2)
      const marker = editor.markScreenRange([[1, 2], [1, 10]])
      editor.decorateMarker(marker, {type: 'highlight', class: 'a'})

      await component.getNextUpdatePromise()
      expect(element.querySelectorAll('.highlight.a').length).toBe(1)

      await setScrollTop(component, component.getLineHeight() * 3)
      expect(element.querySelectorAll('.highlight.a').length).toBe(0)
    })
  })

  describe('overlay decorations', () => {
    function attachFakeWindow (component) {
      const fakeWindow = document.createElement('div')
      fakeWindow.style.position = 'absolute'
      fakeWindow.style.padding = 20 + 'px'
      fakeWindow.style.backgroundColor = 'blue'
      fakeWindow.appendChild(component.element)
      jasmine.attachToDOM(fakeWindow)
      spyOn(component, 'getWindowInnerWidth').andCallFake(() => fakeWindow.getBoundingClientRect().width)
      spyOn(component, 'getWindowInnerHeight').andCallFake(() => fakeWindow.getBoundingClientRect().height)
      return fakeWindow
    }

    it('renders overlay elements at the specified screen position unless it would overflow the window', async () => {
      const {component, element, editor} = buildComponent({width: 200, height: 100, attach: false})
      const fakeWindow = attachFakeWindow(component)

      await setScrollTop(component, 50)
      await setScrollLeft(component, 100)

      const marker = editor.markScreenPosition([4, 25])

      const overlayElement = document.createElement('div')
      overlayElement.style.width = '50px'
      overlayElement.style.height = '50px'
      overlayElement.style.margin = '3px'
      overlayElement.style.backgroundColor = 'red'

      const decoration = editor.decorateMarker(marker, {type: 'overlay', item: overlayElement, class: 'a'})
      await component.getNextUpdatePromise()

      const overlayWrapper = overlayElement.parentElement
      expect(overlayWrapper.classList.contains('a')).toBe(true)
      expect(overlayWrapper.getBoundingClientRect().top).toBe(clientTopForLine(component, 5))
      expect(overlayWrapper.getBoundingClientRect().left).toBe(clientLeftForCharacter(component, 4, 25))

      // Updates the horizontal position on scroll
      await setScrollLeft(component, 150)
      expect(overlayWrapper.getBoundingClientRect().left).toBe(clientLeftForCharacter(component, 4, 25))

      // Shifts the overlay horizontally to ensure the overlay element does not
      // overflow the window
      await setScrollLeft(component, 30)
      expect(overlayElement.getBoundingClientRect().right).toBe(fakeWindow.getBoundingClientRect().right)
      await setScrollLeft(component, 280)
      expect(overlayElement.getBoundingClientRect().left).toBe(fakeWindow.getBoundingClientRect().left)

      // Updates the vertical position on scroll
      await setScrollTop(component, 60)
      expect(overlayWrapper.getBoundingClientRect().top).toBe(clientTopForLine(component, 5))

      // Flips the overlay vertically to ensure the overlay element does not
      // overflow the bottom of the window
      setScrollLeft(component, 100)
      await setScrollTop(component, 0)
      expect(overlayWrapper.getBoundingClientRect().bottom).toBe(clientTopForLine(component, 4))

      // Flips the overlay vertically on overlay resize if necessary
      await setScrollTop(component, 20)
      expect(overlayWrapper.getBoundingClientRect().top).toBe(clientTopForLine(component, 5))
      overlayElement.style.height = 60 + 'px'
      await component.getNextUpdatePromise()
      expect(overlayWrapper.getBoundingClientRect().bottom).toBe(clientTopForLine(component, 4))

      // Does not flip the overlay vertically if it would overflow the top of the window
      overlayElement.style.height = 80 + 'px'
      await component.getNextUpdatePromise()
      expect(overlayWrapper.getBoundingClientRect().top).toBe(clientTopForLine(component, 5))

      // Can update overlay wrapper class
      decoration.setProperties({type: 'overlay', item: overlayElement, class: 'b'})
      await component.getNextUpdatePromise()
      expect(overlayWrapper.classList.contains('a')).toBe(false)
      expect(overlayWrapper.classList.contains('b')).toBe(true)

      decoration.setProperties({type: 'overlay', item: overlayElement})
      await component.getNextUpdatePromise()
      expect(overlayWrapper.classList.contains('b')).toBe(false)
    })

    it('does not attempt to avoid overflowing the window if `avoidOverflow` is false on the decoration', async () => {
      const {component, element, editor} = buildComponent({width: 200, height: 100, attach: false})
      const fakeWindow = attachFakeWindow(component)
      const overlayElement = document.createElement('div')
      overlayElement.style.width = '50px'
      overlayElement.style.height = '50px'
      overlayElement.style.margin = '3px'
      overlayElement.style.backgroundColor = 'red'
      const marker = editor.markScreenPosition([4, 25])
      const decoration = editor.decorateMarker(marker, {type: 'overlay', item: overlayElement, avoidOverflow: false})
      await component.getNextUpdatePromise()

      await setScrollLeft(component, 30)
      expect(overlayElement.getBoundingClientRect().right).toBeGreaterThan(fakeWindow.getBoundingClientRect().right)
      await setScrollLeft(component, 280)
      expect(overlayElement.getBoundingClientRect().left).toBeLessThan(fakeWindow.getBoundingClientRect().left)
    })
  })

  describe('custom gutter decorations', () => {
    it('arranges custom gutters based on their priority', async () => {
      const {component, element, editor} = buildComponent()
      editor.addGutter({name: 'e', priority: 2})
      editor.addGutter({name: 'a', priority: -2})
      editor.addGutter({name: 'd', priority: 1})
      editor.addGutter({name: 'b', priority: -1})
      editor.addGutter({name: 'c', priority: 0})

      await component.getNextUpdatePromise()
      const gutters = component.refs.gutterContainer.querySelectorAll('.gutter')
      expect(Array.from(gutters).map((g) => g.getAttribute('gutter-name'))).toEqual([
        'a', 'b', 'c', 'line-number', 'd', 'e'
      ])
    })

    it('adjusts the left edge of the scroll container based on changes to the gutter container width', async () => {
      const {component, element, editor} = buildComponent()
      const {scrollContainer, gutterContainer} = component.refs

      function checkScrollContainerLeft () {
        expect(scrollContainer.getBoundingClientRect().left).toBe(Math.round(gutterContainer.getBoundingClientRect().right))
      }

      checkScrollContainerLeft()
      const gutterA = editor.addGutter({name: 'a'})
      await component.getNextUpdatePromise()
      checkScrollContainerLeft()

      const gutterB = editor.addGutter({name: 'b'})
      await component.getNextUpdatePromise()
      checkScrollContainerLeft()

      gutterA.getElement().style.width = 100 + 'px'
      await component.getNextUpdatePromise()
      checkScrollContainerLeft()

      gutterA.destroy()
      await component.getNextUpdatePromise()
      checkScrollContainerLeft()

      gutterB.destroy()
      await component.getNextUpdatePromise()
      checkScrollContainerLeft()
    })

    it('allows the element of custom gutters to be retrieved before being rendered in the editor component', async () => {
      const {component, element, editor} = buildComponent()
      const [lineNumberGutter] = editor.getGutters()
      const gutterA = editor.addGutter({name: 'a', priority: -1})
      const gutterB = editor.addGutter({name: 'b', priority: 1})

      const lineNumberGutterElement = lineNumberGutter.getElement()
      const gutterAElement = gutterA.getElement()
      const gutterBElement = gutterB.getElement()

      await component.getNextUpdatePromise()

      expect(element.contains(lineNumberGutterElement)).toBe(true)
      expect(element.contains(gutterAElement)).toBe(true)
      expect(element.contains(gutterBElement)).toBe(true)
    })

    it('can show and hide custom gutters', async () => {
      const {component, element, editor} = buildComponent()
      const gutterA = editor.addGutter({name: 'a', priority: -1})
      const gutterB = editor.addGutter({name: 'b', priority: 1})
      const gutterAElement = gutterA.getElement()
      const gutterBElement = gutterB.getElement()

      await component.getNextUpdatePromise()
      expect(gutterAElement.style.display).toBe('')
      expect(gutterBElement.style.display).toBe('')

      gutterA.hide()
      await component.getNextUpdatePromise()
      expect(gutterAElement.style.display).toBe('none')
      expect(gutterBElement.style.display).toBe('')

      gutterB.hide()
      await component.getNextUpdatePromise()
      expect(gutterAElement.style.display).toBe('none')
      expect(gutterBElement.style.display).toBe('none')

      gutterA.show()
      await component.getNextUpdatePromise()
      expect(gutterAElement.style.display).toBe('')
      expect(gutterBElement.style.display).toBe('none')
    })

    it('renders decorations in custom gutters', async () => {
      const {component, element, editor} = buildComponent()
      const gutterA = editor.addGutter({name: 'a', priority: -1})
      const gutterB = editor.addGutter({name: 'b', priority: 1})
      const marker1 = editor.markScreenRange([[2, 0], [4, 0]])
      const marker2 = editor.markScreenRange([[6, 0], [7, 0]])
      const marker3 = editor.markScreenRange([[9, 0], [12, 0]])
      const decorationElement1 = document.createElement('div')
      const decorationElement2 = document.createElement('div')

      const decoration1 = gutterA.decorateMarker(marker1, {class: 'a'})
      const decoration2 = gutterA.decorateMarker(marker2, {class: 'b', item: decorationElement1})
      const decoration3 = gutterB.decorateMarker(marker3, {item: decorationElement2})
      await component.getNextUpdatePromise()

      let [decorationNode1, decorationNode2] = gutterA.getElement().firstChild.children
      const [decorationNode3] = gutterB.getElement().firstChild.children

      expect(decorationNode1.className).toBe('a')
      expect(decorationNode1.getBoundingClientRect().top).toBe(clientTopForLine(component, 2))
      expect(decorationNode1.getBoundingClientRect().bottom).toBe(clientTopForLine(component, 5))
      expect(decorationNode1.firstChild).toBeNull()

      expect(decorationNode2.className).toBe('b')
      expect(decorationNode2.getBoundingClientRect().top).toBe(clientTopForLine(component, 6))
      expect(decorationNode2.getBoundingClientRect().bottom).toBe(clientTopForLine(component, 8))
      expect(decorationNode2.firstChild).toBe(decorationElement1)

      expect(decorationNode3.className).toBe('')
      expect(decorationNode3.getBoundingClientRect().top).toBe(clientTopForLine(component, 9))
      expect(decorationNode3.getBoundingClientRect().bottom).toBe(clientTopForLine(component, 12) + component.getLineHeight())
      expect(decorationNode3.firstChild).toBe(decorationElement2)

      decoration1.setProperties({type: 'gutter', gutterName: 'a', class: 'c', item: decorationElement1})
      decoration2.setProperties({type: 'gutter', gutterName: 'a', item: decorationElement2})
      decoration3.destroy()
      await component.getNextUpdatePromise()
      expect(decorationNode1.className).toBe('c')
      expect(decorationNode1.firstChild).toBe(decorationElement1)
      expect(decorationNode2.className).toBe('')
      expect(decorationNode2.firstChild).toBe(decorationElement2)
      expect(gutterB.getElement().firstChild.children.length).toBe(0)
    })
  })

  describe('block decorations', () => {
    it('renders visible block decorations between the appropriate lines, refreshing and measuring them as needed', async () => {
      const editor = buildEditor({autoHeight: false})
      const {item: item1, decoration: decoration1} = createBlockDecorationAtScreenRow(editor, 0, {height: 11, position: 'before'})
      const {item: item2, decoration: decoration2} = createBlockDecorationAtScreenRow(editor, 2, {height: 22, margin: 10, position: 'before'})

      // render an editor that already contains some block decorations
      const {component, element} = buildComponent({editor, rowsPerTile: 3})
      await setEditorHeightInLines(component, 4)
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item1) + getElementHeight(item2)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item1) + getElementHeight(item2)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(item1.previousSibling).toBeNull()
      expect(item1.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2))

      // add block decorations
      const {item: item3, decoration: decoration3} = createBlockDecorationAtScreenRow(editor, 4, {height: 33, position: 'before'})
      const {item: item4, decoration: decoration4} = createBlockDecorationAtScreenRow(editor, 7, {height: 44, position: 'before'})
      const {item: item5, decoration: decoration5} = createBlockDecorationAtScreenRow(editor, 7, {height: 55, position: 'after'})
      const {item: item6, decoration: decoration6} = createBlockDecorationAtScreenRow(editor, 12, {height: 66, position: 'after'})
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item1) + getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item1) + getElementHeight(item2)},
        {tileStartRow: 3, height: 3 * component.getLineHeight() + getElementHeight(item3)}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(item1.previousSibling).toBeNull()
      expect(item1.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2))
      expect(item3.previousSibling).toBe(lineNodeForScreenRow(component, 3))
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 4))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // scroll past the first tile
      await setScrollTop(component, 3 * component.getLineHeight() + getElementHeight(item1) + getElementHeight(item2))
      expect(component.getRenderedStartRow()).toBe(3)
      expect(component.getRenderedEndRow()).toBe(9)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item1) + getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 3, height: 3 * component.getLineHeight() + getElementHeight(item3)},
        {tileStartRow: 6, height: 3 * component.getLineHeight() + getElementHeight(item4) + getElementHeight(item5)}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(element.contains(item2)).toBe(false)
      expect(item3.previousSibling).toBe(lineNodeForScreenRow(component, 3))
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 4))
      expect(item4.previousSibling).toBe(lineNodeForScreenRow(component, 6))
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7))
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7))
      expect(item5.nextSibling).toBe(lineNodeForScreenRow(component, 8))
      expect(element.contains(item6)).toBe(false)

      // destroy decoration1
      await setScrollTop(component, 0)
      decoration1.destroy()
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2)},
        {tileStartRow: 3, height: 3 * component.getLineHeight() + getElementHeight(item3)}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2))
      expect(item3.previousSibling).toBe(lineNodeForScreenRow(component, 3))
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 4))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // move decoration2 and decoration3
      decoration2.getMarker().setHeadScreenPosition([1, 0])
      decoration3.getMarker().setHeadScreenPosition([0, 0])
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2) + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // change the text
      editor.getBuffer().setTextInRange([[0, 5], [0, 5]], '\n\n')
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight() + getElementHeight(item2)}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBeNull()
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 3))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // undo the previous change
      editor.undo()
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2) + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // invalidate decorations. this also tests a case where two decorations in
      // the same tile change their height without affecting the tile height nor
      // the content height.
      item3.style.height = '22px'
      item3.style.margin = '10px'
      item2.style.height = '33px'
      item2.style.margin = '0px'
      component.invalidateBlockDecorationDimensions(decoration2)
      component.invalidateBlockDecorationDimensions(decoration3)
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2) + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // make decoration before row 0 as wide as the editor, and insert some text into it so that it wraps.
      item3.style.height = ''
      item3.style.margin = ''
      item3.style.width = ''
      item3.style.wordWrap = 'break-word'
      const contentWidthInCharacters = Math.floor(component.getScrollContainerClientWidth() / component.getBaseCharacterWidth())
      item3.textContent = 'x'.repeat(contentWidthInCharacters * 2)
      component.invalidateBlockDecorationDimensions(decoration3)
      await component.getNextUpdatePromise()

      // make the editor wider, so that the decoration doesn't wrap anymore.
      component.element.style.width = (
        component.getGutterContainerWidth() +
        component.getScrollContainerClientWidth() * 2 +
        component.getVerticalScrollbarWidth()
      ) + 'px'
      await component.getNextUpdatePromise()
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(6)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2) + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()}
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(6)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(element.contains(item4)).toBe(false)
      expect(element.contains(item5)).toBe(false)
      expect(element.contains(item6)).toBe(false)

      // make the editor taller and wider and the same time, ensuring the number
      // of rendered lines is correct.
      setEditorHeightInLines(component, 10)
      await setEditorWidthInCharacters(component, 50)
      expect(component.getRenderedStartRow()).toBe(0)
      expect(component.getRenderedEndRow()).toBe(9)
      expect(component.getScrollHeight()).toBe(
        editor.getScreenLineCount() * component.getLineHeight() +
        getElementHeight(item2) + getElementHeight(item3) +
        getElementHeight(item4) + getElementHeight(item5) + getElementHeight(item6)
      )
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {tileStartRow: 0, height: 3 * component.getLineHeight() + getElementHeight(item2) + getElementHeight(item3)},
        {tileStartRow: 3, height: 3 * component.getLineHeight()},
        {tileStartRow: 6, height: 3 * component.getLineHeight() + getElementHeight(item4) + getElementHeight(item5)},
      ])
      assertLinesAreAlignedWithLineNumbers(component)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBe(9)
      expect(element.contains(item1)).toBe(false)
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1))
      expect(item3.previousSibling).toBeNull()
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0))
      expect(item4.previousSibling).toBe(lineNodeForScreenRow(component, 6))
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7))
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7))
      expect(item5.nextSibling).toBe(lineNodeForScreenRow(component, 8))
      expect(element.contains(item6)).toBe(false)
    })

    function createBlockDecorationAtScreenRow(editor, screenRow, {height, margin, position}) {
      const marker = editor.markScreenPosition([screenRow, 0], {invalidate: 'never'})
      const item = document.createElement('div')
      item.style.height = height + 'px'
      if (margin != null) item.style.margin = margin + 'px'
      item.style.width = 30 + 'px'
      const decoration = editor.decorateMarker(marker, {type: 'block', item, position})
      return {item, decoration}
    }

    function assertTilesAreSizedAndPositionedCorrectly (component, tiles) {
      let top = 0
      for (let tile of tiles) {
        const linesTileElement = lineNodeForScreenRow(component, tile.tileStartRow).parentElement
        const linesTileBoundingRect = linesTileElement.getBoundingClientRect()
        expect(linesTileBoundingRect.height).toBe(tile.height)
        expect(linesTileBoundingRect.top).toBe(top)

        const lineNumbersTileElement = lineNumberNodeForScreenRow(component, tile.tileStartRow).parentElement
        const lineNumbersTileBoundingRect = lineNumbersTileElement.getBoundingClientRect()
        expect(lineNumbersTileBoundingRect.height).toBe(tile.height)
        expect(lineNumbersTileBoundingRect.top).toBe(top)

        top += tile.height
      }
    }

    function assertLinesAreAlignedWithLineNumbers (component) {
      const startRow = component.getRenderedStartRow()
      const endRow = component.getRenderedEndRow()
      for (let row = startRow; row < endRow; row++) {
        const lineNode = lineNodeForScreenRow(component, row)
        const lineNumberNode = lineNumberNodeForScreenRow(component, row)
        expect(lineNumberNode.getBoundingClientRect().top).toBe(lineNode.getBoundingClientRect().top)
      }
    }
  })

  describe('mouse input', () => {
    describe('on the lines', () => {
      it('positions the cursor on single-click', async () => {
        const {component, element, editor} = buildComponent()
        const {lineHeight} = component.measurements

        editor.setCursorScreenPosition([Infinity, Infinity], {autoscroll: false})
        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: clientLeftForCharacter(component, 0, 0) - 1,
          clientY: clientTopForLine(component, 0) - 1
        })
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])

        const maxRow = editor.getLastScreenRow()
        editor.setCursorScreenPosition([Infinity, Infinity], {autoscroll: false})
        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: clientLeftForCharacter(component, maxRow, editor.lineLengthForScreenRow(maxRow)) + 1,
          clientY: clientTopForLine(component, maxRow) + 1
        })
        expect(editor.getCursorScreenPosition()).toEqual([maxRow, editor.lineLengthForScreenRow(maxRow)])

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: clientLeftForCharacter(component, 0, editor.lineLengthForScreenRow(0)) + 1,
          clientY: clientTopForLine(component, 0) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([0, editor.lineLengthForScreenRow(0)])

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: (clientLeftForCharacter(component, 3, 0) + clientLeftForCharacter(component, 3, 1)) / 2,
          clientY: clientTopForLine(component, 1) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([1, 0])

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: (clientLeftForCharacter(component, 3, 14) + clientLeftForCharacter(component, 3, 15)) / 2,
          clientY: clientTopForLine(component, 3) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([3, 14])

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: (clientLeftForCharacter(component, 3, 14) + clientLeftForCharacter(component, 3, 15)) / 2 + 1,
          clientY: clientTopForLine(component, 3) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([3, 15])

        editor.getBuffer().setTextInRange([[3, 14], [3, 15]], '🐣')
        await component.getNextUpdatePromise()

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: (clientLeftForCharacter(component, 3, 14) + clientLeftForCharacter(component, 3, 16)) / 2,
          clientY: clientTopForLine(component, 3) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([3, 14])

        component.didMouseDownOnContent({
          detail: 1,
          button: 0,
          clientX: (clientLeftForCharacter(component, 3, 14) + clientLeftForCharacter(component, 3, 16)) / 2 + 1,
          clientY: clientTopForLine(component, 3) + lineHeight / 2
        })
        expect(editor.getCursorScreenPosition()).toEqual([3, 16])
      })

      it('selects words on double-click', () => {
        const {component, editor} = buildComponent()
        const {clientX, clientY} = clientPositionForCharacter(component, 1, 16)
        component.didMouseDownOnContent({detail: 1, button: 0, clientX, clientY})
        component.didMouseDownOnContent({detail: 2, button: 0, clientX, clientY})
        expect(editor.getSelectedScreenRange()).toEqual([[1, 13], [1, 21]])
      })

      it('selects lines on triple-click', () => {
        const {component, editor} = buildComponent()
        const {clientX, clientY} = clientPositionForCharacter(component, 1, 16)
        component.didMouseDownOnContent({detail: 1, button: 0, clientX, clientY})
        component.didMouseDownOnContent({detail: 2, button: 0, clientX, clientY})
        component.didMouseDownOnContent({detail: 3, button: 0, clientX, clientY})
        expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [2, 0]])
      })

      it('adds or removes cursors when holding cmd or ctrl when single-clicking', () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'getPlatform').andCallFake(() => mockedPlatform)

        let mockedPlatform = 'darwin'
        expect(editor.getCursorScreenPositions()).toEqual([[0, 0]])

        // add cursor at 1, 16
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 16), {
            detail: 1,
            button: 0,
            metaKey: true
          })
        )
        expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]])

        // remove cursor at 0, 0
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 0, 0), {
            detail: 1,
            button: 0,
            metaKey: true
          })
        )
        expect(editor.getCursorScreenPositions()).toEqual([[1, 16]])

        // cmd-click cursor at 1, 16 but don't remove it because it's the last one
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 16), {
            detail: 1,
            button: 0,
            metaKey: true
          })
        )
        expect(editor.getCursorScreenPositions()).toEqual([[1, 16]])

        // cmd-clicking within a selection destroys it
        editor.addSelectionForScreenRange([[2, 10], [2, 15]])
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[1, 16], [1, 16]],
          [[2, 10], [2, 15]]
        ])
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 2, 13), {
            detail: 1,
            button: 0,
            metaKey: true
          })
        )
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[1, 16], [1, 16]]
        ])

        // ctrl-click does not add cursors on macOS
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 4), {
            detail: 1,
            button: 0,
            ctrlKey: true
          })
        )
        expect(editor.getCursorScreenPositions()).toEqual([[1, 4]])

        mockedPlatform = 'win32'

        // ctrl-click adds cursors on platforms *other* than macOS
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 16), {
            detail: 1,
            button: 0,
            ctrlKey: true
          })
        )
        expect(editor.getCursorScreenPositions()).toEqual([[1, 4], [1, 16]])
      })

      it('adds word selections when holding cmd or ctrl when double-clicking', () => {
        const {component, editor} = buildComponent()
        editor.addCursorAtScreenPosition([1, 16])
        expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]])

        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 16), {
            detail: 1,
            button: 0,
            metaKey: true
          })
        )
        component.didMouseDownOnContent(
          Object.assign(clientPositionForCharacter(component, 1, 16), {
            detail: 2,
            button: 0,
            metaKey: true
          })
        )
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[1, 13], [1, 21]]
        ])
      })

      it('adds line selections when holding cmd or ctrl when triple-clicking', () => {
        const {component, editor} = buildComponent()
        editor.addCursorAtScreenPosition([1, 16])
        expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]])

        const {clientX, clientY} = clientPositionForCharacter(component, 1, 16)
        component.didMouseDownOnContent({detail: 1, button: 0, metaKey: true, clientX, clientY})
        component.didMouseDownOnContent({detail: 2, button: 0, metaKey: true, clientX, clientY})
        component.didMouseDownOnContent({detail: 3, button: 0, metaKey: true, clientX, clientY})

        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[1, 0], [2, 0]]
        ])
      })

      it('expands the last selection on shift-click', () => {
        const {component, element, editor} = buildComponent()

        editor.setCursorScreenPosition([2, 18])
        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 1, 4)))
        expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [2, 18]])

        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 4, 4)))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 18], [4, 4]])

        // reorients word-wise selections to keep the word selected regardless of
        // where the subsequent shift-click occurs
        editor.setCursorScreenPosition([2, 18])
        editor.getLastSelection().selectWord()
        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 1, 4)))
        expect(editor.getSelectedScreenRange()).toEqual([[1, 2], [2, 20]])

        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 3, 11)))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 14], [3, 13]])

        // reorients line-wise selections to keep the word selected regardless of
        // where the subsequent shift-click occurs
        editor.setCursorScreenPosition([2, 18])
        editor.getLastSelection().selectLine()
        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 1, 4)))
        expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 0]])

        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          shiftKey: true
        }, clientPositionForCharacter(component, 3, 11)))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [4, 0]])
      })

      it('expands the last selection on drag', () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')

        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
        }, clientPositionForCharacter(component, 1, 4)))

        {
          const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[0][0]
          didDrag(clientPositionForCharacter(component, 8, 8))
          expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [8, 8]])
          didDrag(clientPositionForCharacter(component, 4, 8))
          expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [4, 8]])
          didStopDragging()
          expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [4, 8]])
        }

        // Click-drag a second selection... selections are not merged until the
        // drag stops.
        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
          metaKey: 1,
        }, clientPositionForCharacter(component, 8, 8)))
        {
          const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[1][0]
          didDrag(clientPositionForCharacter(component, 2, 8))
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 4], [4, 8]],
            [[2, 8], [8, 8]]
          ])
          didDrag(clientPositionForCharacter(component, 6, 8))
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 4], [4, 8]],
            [[6, 8], [8, 8]]
          ])
          didDrag(clientPositionForCharacter(component, 2, 8))
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 4], [4, 8]],
            [[2, 8], [8, 8]]
          ])
          didStopDragging()
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 4], [8, 8]]
          ])
        }
      })

      it('expands the selection word-wise on double-click-drag', () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')

        component.didMouseDownOnContent(Object.assign({
          detail: 1,
          button: 0,
        }, clientPositionForCharacter(component, 1, 4)))
        component.didMouseDownOnContent(Object.assign({
          detail: 2,
          button: 0,
        }, clientPositionForCharacter(component, 1, 4)))

        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[1][0]
        didDrag(clientPositionForCharacter(component, 0, 8))
        expect(editor.getSelectedScreenRange()).toEqual([[0, 4], [1, 5]])
        didDrag(clientPositionForCharacter(component, 2, 10))
        expect(editor.getSelectedScreenRange()).toEqual([[1, 2], [2, 13]])
      })

      it('expands the selection line-wise on triple-click-drag', () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')

        const tripleClickPosition = clientPositionForCharacter(component, 2, 8)
        component.didMouseDownOnContent(Object.assign({detail: 1, button: 0}, tripleClickPosition))
        component.didMouseDownOnContent(Object.assign({detail: 2, button: 0}, tripleClickPosition))
        component.didMouseDownOnContent(Object.assign({detail: 3, button: 0}, tripleClickPosition))

        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[2][0]
        didDrag(clientPositionForCharacter(component, 1, 8))
        expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 0]])
        didDrag(clientPositionForCharacter(component, 4, 10))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [5, 0]])
      })

      it('destroys folds when clicking on their fold markers', async () => {
        const {component, element, editor} = buildComponent()
        editor.foldBufferRow(1)
        await component.getNextUpdatePromise()

        const target = element.querySelector('.fold-marker')
        const {clientX, clientY} = clientPositionForCharacter(component, 1, editor.lineLengthForScreenRow(1))
        component.didMouseDownOnContent({detail: 1, button: 0, target, clientX, clientY})
        expect(editor.isFoldedAtBufferRow(1)).toBe(false)
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      })

      it('autoscrolls the content when dragging near the edge of the scroll container', async () => {
        const {component, element, editor} = buildComponent({width: 200, height: 200})
        spyOn(component, 'handleMouseDragUntilMouseUp')

        let previousScrollTop = 0
        let previousScrollLeft = 0
        function assertScrolledDownAndRight () {
          expect(component.getScrollTop()).toBeGreaterThan(previousScrollTop)
          previousScrollTop = component.getScrollTop()
          expect(component.getScrollLeft()).toBeGreaterThan(previousScrollLeft)
          previousScrollLeft = component.getScrollLeft()
        }

        function assertScrolledUpAndLeft () {
          expect(component.getScrollTop()).toBeLessThan(previousScrollTop)
          previousScrollTop = component.getScrollTop()
          expect(component.getScrollLeft()).toBeLessThan(previousScrollLeft)
          previousScrollLeft = component.getScrollLeft()
        }

        component.didMouseDownOnContent({detail: 1, button: 0, clientX: 100, clientY: 100})
        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[0][0]

        didDrag({clientX: 199, clientY: 199})
        assertScrolledDownAndRight()
        didDrag({clientX: 199, clientY: 199})
        assertScrolledDownAndRight()
        didDrag({clientX: 199, clientY: 199})
        assertScrolledDownAndRight()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUpAndLeft()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUpAndLeft()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUpAndLeft()

        // Don't artificially update scroll position beyond possible values
        expect(component.getScrollTop()).toBe(0)
        expect(component.getScrollLeft()).toBe(0)
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        expect(component.getScrollTop()).toBe(0)
        expect(component.getScrollLeft()).toBe(0)

        const maxScrollTop = component.getMaxScrollTop()
        const maxScrollLeft = component.getMaxScrollLeft()
        setScrollTop(component, maxScrollTop)
        await setScrollLeft(component, maxScrollLeft)

        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        expect(component.getScrollTop()).toBe(maxScrollTop)
        expect(component.getScrollLeft()).toBe(maxScrollLeft)
      })
    })

    describe('on the line number gutter', () => {
      it('selects all buffer rows intersecting the clicked screen row when a line number is clicked', async () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')
        editor.setSoftWrapped(true)
        await component.getNextUpdatePromise()

        await setEditorWidthInCharacters(component, 50)
        editor.foldBufferRange([[4, Infinity], [7, Infinity]])
        await component.getNextUpdatePromise()

        // Selects entire buffer line when clicked screen line is soft-wrapped
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          clientY: clientTopForLine(component, 3)
        })
        expect(editor.getSelectedScreenRange()).toEqual([[3, 0], [5, 0]])
        expect(editor.getSelectedBufferRange()).toEqual([[3, 0], [4, 0]])

        // Selects entire screen line, even if folds cause that selection to
        // span multiple buffer lines
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          clientY: clientTopForLine(component, 5)
        })
        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]])
        expect(editor.getSelectedBufferRange()).toEqual([[4, 0], [8, 0]])
      })

      it('adds new selections when a line number is meta-clicked', async () => {
        const {component, editor} = buildComponent()
        editor.setSoftWrapped(true)
        await component.getNextUpdatePromise()

        await setEditorWidthInCharacters(component, 50)
        editor.foldBufferRange([[4, Infinity], [7, Infinity]])
        await component.getNextUpdatePromise()

        // Selects entire buffer line when clicked screen line is soft-wrapped
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 3)
        })
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [5, 0]]
        ])
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [4, 0]]
        ])

        // Selects entire screen line, even if folds cause that selection to
        // span multiple buffer lines
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 5)
        })
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [5, 0]],
          [[5, 0], [6, 0]]
        ])
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [4, 0]],
          [[4, 0], [8, 0]]
        ])
      })

      it('expands the last selection when a line number is shift-clicked', async () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')
        editor.setSoftWrapped(true)
        await component.getNextUpdatePromise()

        await setEditorWidthInCharacters(component, 50)
        editor.foldBufferRange([[4, Infinity], [7, Infinity]])
        await component.getNextUpdatePromise()

        editor.setSelectedScreenRange([[3, 4], [3, 8]])
        editor.addCursorAtScreenPosition([2, 10])
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          shiftKey: true,
          clientY: clientTopForLine(component, 5)
        })

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 4], [3, 8]],
          [[2, 10], [8, 0]]
        ])

        // Original selection is preserved when shift-click-dragging
        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[0][0]
        didDrag({
          clientY: clientTopForLine(component, 1)
        })
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 4], [3, 8]],
          [[1, 0], [2, 10]]
        ])

        didDrag({
          clientY: clientTopForLine(component, 5)
        })

        didStopDragging()
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 10], [8, 0]]
        ])
      })

      it('expands the selection when dragging', async () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')
        editor.setSoftWrapped(true)
        await component.getNextUpdatePromise()

        await setEditorWidthInCharacters(component, 50)
        editor.foldBufferRange([[4, Infinity], [7, Infinity]])
        await component.getNextUpdatePromise()

        editor.setSelectedScreenRange([[3, 4], [3, 6]])

        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 2)
        })

        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[0][0]

        didDrag({
          clientY: clientTopForLine(component, 1)
        })
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[1, 0], [3, 0]]
        ])

        didDrag({
          clientY: clientTopForLine(component, 5)
        })
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[2, 0], [6, 0]]
        ])
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        didDrag({
          clientY: clientTopForLine(component, 3)
        })
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[2, 0], [4, 4]]
        ])

        didStopDragging()
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[2, 0], [4, 4]]
        ])
      })

      it('toggles folding when clicking on the right icon of a foldable line number', async () => {
        const {component, element, editor} = buildComponent()
        const target = element.querySelectorAll('.line-number')[1].querySelector('.icon-right')
        expect(editor.isFoldedAtScreenRow(1)).toBe(false)

        component.didMouseDownOnLineNumberGutter({target, button: 0, clientY: clientTopForLine(component, 1)})
        expect(editor.isFoldedAtScreenRow(1)).toBe(true)
        await component.getNextUpdatePromise()

        component.didMouseDownOnLineNumberGutter({target, button: 0, clientY: clientTopForLine(component, 1)})
        expect(editor.isFoldedAtScreenRow(1)).toBe(false)
      })

      it('autoscrolls when dragging near the top or bottom of the gutter', async () => {
        const {component, editor} = buildComponent({width: 200, height: 200})
        const {scrollContainer} = component.refs
        spyOn(component, 'handleMouseDragUntilMouseUp')

        let previousScrollTop = 0
        let previousScrollLeft = 0
        function assertScrolledDown () {
          expect(component.getScrollTop()).toBeGreaterThan(previousScrollTop)
          previousScrollTop = component.getScrollTop()
          expect(component.getScrollLeft()).toBe(previousScrollLeft)
          previousScrollLeft = component.getScrollLeft()
        }

        function assertScrolledUp () {
          expect(component.getScrollTop()).toBeLessThan(previousScrollTop)
          previousScrollTop = component.getScrollTop()
          expect(component.getScrollLeft()).toBe(previousScrollLeft)
          previousScrollLeft = component.getScrollLeft()
        }

        component.didMouseDownOnLineNumberGutter({detail: 1, button: 0, clientX: 0, clientY: 100})
        const {didDrag, didStopDragging} = component.handleMouseDragUntilMouseUp.argsForCall[0][0]
        didDrag({clientX: 199, clientY: 199})
        assertScrolledDown()
        didDrag({clientX: 199, clientY: 199})
        assertScrolledDown()
        didDrag({clientX: 199, clientY: 199})
        assertScrolledDown()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUp()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUp()
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        assertScrolledUp()

        // Don't artificially update scroll measurements beyond the minimum or
        // maximum possible scroll positions
        expect(component.getScrollTop()).toBe(0)
        expect(component.getScrollLeft()).toBe(0)
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        expect(component.getScrollTop()).toBe(0)
        expect(component.getScrollLeft()).toBe(0)

        const maxScrollTop = component.getMaxScrollTop()
        const maxScrollLeft = component.getMaxScrollLeft()
        setScrollTop(component, maxScrollTop)
        await setScrollLeft(component, maxScrollLeft)

        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        expect(component.getScrollTop()).toBe(maxScrollTop)
        expect(component.getScrollLeft()).toBe(maxScrollLeft)
      })
    })

    describe('on the scrollbars', () => {
      it('delegates the mousedown events to the parent component unless the mousedown was on the actual scrollbar', () => {
        const {component, element, editor} = buildComponent({height: 100, width: 100})
        const verticalScrollbar = component.refs.verticalScrollbar
        const horizontalScrollbar = component.refs.horizontalScrollbar

        const leftEdgeOfVerticalScrollbar = verticalScrollbar.element.getBoundingClientRect().right - getVerticalScrollbarWidth(component)
        const topEdgeOfHorizontalScrollbar = horizontalScrollbar.element.getBoundingClientRect().bottom - getHorizontalScrollbarHeight(component)

        verticalScrollbar.didMousedown({
          button: 0,
          detail: 1,
          clientY: clientTopForLine(component, 4),
          clientX: leftEdgeOfVerticalScrollbar
        })
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])

        verticalScrollbar.didMousedown({
          button: 0,
          detail: 1,
          clientY: clientTopForLine(component, 4),
          clientX: leftEdgeOfVerticalScrollbar - 1
        })
        expect(editor.getCursorScreenPosition()).toEqual([4, 6])

        horizontalScrollbar.didMousedown({
          button: 0,
          detail: 1,
          clientY: topEdgeOfHorizontalScrollbar,
          clientX: component.refs.content.getBoundingClientRect().left
        })
        expect(editor.getCursorScreenPosition()).toEqual([4, 6])

        horizontalScrollbar.didMousedown({
          button: 0,
          detail: 1,
          clientY: topEdgeOfHorizontalScrollbar - 1,
          clientX: component.refs.content.getBoundingClientRect().left
        })
        expect(editor.getCursorScreenPosition()).toEqual([4, 0])
      })
    })
  })

  describe('styling changes', () => {
    it('updates the rendered content based on new measurements when the font dimensions change', async () => {
      const {component, element, editor} = buildComponent({rowsPerTile: 1, autoHeight: false})
      await setEditorHeightInLines(component, 3)
      editor.setCursorScreenPosition([1, 29], {autoscroll: false})
      await component.getNextUpdatePromise()

      let cursorNode = element.querySelector('.cursor')
      const initialBaseCharacterWidth = editor.getDefaultCharWidth()
      const initialDoubleCharacterWidth = editor.getDoubleWidthCharWidth()
      const initialHalfCharacterWidth = editor.getHalfWidthCharWidth()
      const initialKoreanCharacterWidth = editor.getKoreanCharWidth()
      const initialRenderedLineCount = element.querySelectorAll('.line:not(.dummy)').length
      const initialFontSize = parseInt(getComputedStyle(element).fontSize)

      expect(initialKoreanCharacterWidth).toBeDefined()
      expect(initialDoubleCharacterWidth).toBeDefined()
      expect(initialHalfCharacterWidth).toBeDefined()
      expect(initialBaseCharacterWidth).toBeDefined()
      expect(initialDoubleCharacterWidth).not.toBe(initialBaseCharacterWidth)
      expect(initialHalfCharacterWidth).not.toBe(initialBaseCharacterWidth)
      expect(initialKoreanCharacterWidth).not.toBe(initialBaseCharacterWidth)
      verifyCursorPosition(component, cursorNode, 1, 29)

      element.style.fontSize = initialFontSize - 5 + 'px'
      TextEditor.didUpdateStyles()
      await component.getNextUpdatePromise()
      expect(editor.getDefaultCharWidth()).toBeLessThan(initialBaseCharacterWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeLessThan(initialDoubleCharacterWidth)
      expect(editor.getHalfWidthCharWidth()).toBeLessThan(initialHalfCharacterWidth)
      expect(editor.getKoreanCharWidth()).toBeLessThan(initialKoreanCharacterWidth)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBeGreaterThan(initialRenderedLineCount)
      verifyCursorPosition(component, cursorNode, 1, 29)

      element.style.fontSize = initialFontSize + 5 + 'px'
      TextEditor.didUpdateStyles()
      await component.getNextUpdatePromise()
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(initialBaseCharacterWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeGreaterThan(initialDoubleCharacterWidth)
      expect(editor.getHalfWidthCharWidth()).toBeGreaterThan(initialHalfCharacterWidth)
      expect(editor.getKoreanCharWidth()).toBeGreaterThan(initialKoreanCharacterWidth)
      expect(element.querySelectorAll('.line:not(.dummy)').length).toBeLessThan(initialRenderedLineCount)
      verifyCursorPosition(component, cursorNode, 1, 29)
    })

    it('gracefully handles the editor being hidden after a styling change', async () => {
      const {component, element, editor} = buildComponent({autoHeight: false})
      element.style.fontSize = parseInt(getComputedStyle(element).fontSize) + 5 + 'px'
      TextEditor.didUpdateStyles()
      element.style.display = 'none'
      await component.getNextUpdatePromise()
    })
  })
})

function buildEditor (params = {}) {
  const text = params.text != null ? params.text : SAMPLE_TEXT
  const buffer = new TextBuffer({text})
  const editorParams = {buffer}
  if (params.height != null) params.autoHeight = false
  for (const paramName of ['mini', 'autoHeight', 'autoWidth', 'lineNumberGutterVisible', 'placeholderText']) {
    if (params[paramName] != null) editorParams[paramName] = params[paramName]
  }
  return new TextEditor(editorParams)
}

function buildComponent (params = {}) {
  const editor = params.editor || buildEditor(params)
  const component = new TextEditorComponent({
    model: editor,
    rowsPerTile: params.rowsPerTile,
    updatedSynchronously: false
  })
  const {element} = component
  if (!editor.getAutoHeight()) {
    element.style.height = params.height ? params.height + 'px' : '600px'
  }
  if (!editor.getAutoWidth()) {
    element.style.width = params.width ? params.width + 'px' : '800px'
  }
  if (params.attach !== false) jasmine.attachToDOM(element)
  return {component, element, editor}
}

function getEditorWidthInBaseCharacters (component) {
  return Math.round(component.getScrollContainerWidth() / component.getBaseCharacterWidth())
}

async function setEditorHeightInLines(component, heightInLines) {
  component.element.style.height = component.getLineHeight() * heightInLines + 'px'
  await component.getNextUpdatePromise()
}

async function setEditorWidthInCharacters (component, widthInCharacters) {
  component.element.style.width =
    component.getGutterContainerWidth() +
    widthInCharacters * component.measurements.baseCharacterWidth +
    'px'
  await component.getNextUpdatePromise()
}

function verifyCursorPosition (component, cursorNode, row, column) {
  const rect = cursorNode.getBoundingClientRect()
  expect(Math.round(rect.top)).toBe(clientTopForLine(component, row))
  expect(Math.round(rect.left)).toBe(clientLeftForCharacter(component, row, column))
}

function clientTopForLine (component, row) {
  return lineNodeForScreenRow(component, row).getBoundingClientRect().top
}

function clientLeftForCharacter (component, row, column) {
  const textNodes = textNodesForScreenRow(component, row)
  let textNodeStartColumn = 0
  for (const textNode of textNodes) {
    const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length
    if (column <= textNodeEndColumn) {
      const range = document.createRange()
      range.setStart(textNode, column - textNodeStartColumn)
      range.setEnd(textNode, column - textNodeStartColumn)
      return range.getBoundingClientRect().left
    }
    textNodeStartColumn = textNodeEndColumn
  }
}

function clientPositionForCharacter (component, row, column) {
  return {
    clientX: clientLeftForCharacter(component, row, column),
    clientY: clientTopForLine(component, row)
  }
}

function lineNumberNodeForScreenRow (component, row) {
  const gutterElement = component.refs.lineNumberGutter.element
  const tileStartRow = component.tileStartRowForRow(row)
  const tileIndex = component.tileIndexForTileStartRow(tileStartRow)
  return gutterElement.children[tileIndex + 1].children[row - tileStartRow]
}

function lineNodeForScreenRow (component, row) {
  const renderedScreenLine = component.renderedScreenLineForRow(row)
  return component.lineNodesByScreenLineId.get(renderedScreenLine.id)
}

function textNodesForScreenRow (component, row) {
  const screenLine = component.renderedScreenLineForRow(row)
  return component.textNodesByScreenLineId.get(screenLine.id)
}

function setScrollTop (component, scrollTop) {
  component.setScrollTop(scrollTop)
  component.scheduleUpdate()
  return component.getNextUpdatePromise()
}

function setScrollLeft (component, scrollLeft) {
  component.setScrollLeft(scrollLeft)
  component.scheduleUpdate()
  return component.getNextUpdatePromise()
}

function getHorizontalScrollbarHeight (component) {
  const element = component.refs.horizontalScrollbar.element
  return element.offsetHeight - element.clientHeight
}

function getVerticalScrollbarWidth (component) {
  const element = component.refs.verticalScrollbar.element
  return element.offsetWidth - element.clientWidth
}

function assertDocumentFocused () {
  if (!document.hasFocus()) {
    throw new Error('The document needs to be focused to run this test')
  }
}

function getElementHeight (element) {
  const topRuler = document.createElement('div')
  const bottomRuler = document.createElement('div')
  let height
  if (document.body.contains(element)) {
    element.parentElement.insertBefore(topRuler, element)
    element.parentElement.insertBefore(bottomRuler, element.nextSibling)
    height = bottomRuler.offsetTop - topRuler.offsetTop
  } else {
    jasmine.attachToDOM(topRuler)
    jasmine.attachToDOM(element)
    jasmine.attachToDOM(bottomRuler)
    height = bottomRuler.offsetTop - topRuler.offsetTop
    element.remove()
  }

  topRuler.remove()
  bottomRuler.remove()
  return height
}
