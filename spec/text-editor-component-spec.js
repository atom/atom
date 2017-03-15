/** @babel */

import {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise} from './async-spec-helpers'

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

  it('renders lines and line numbers for the visible region', async () => {
    const {component, element, editor} = buildComponent({rowsPerTile: 3})

    expect(element.querySelectorAll('.line-number').length).toBe(13)
    expect(element.querySelectorAll('.line').length).toBe(13)

    element.style.height = 4 * component.measurements.lineHeight + 'px'
    await component.getNextUpdatePromise()
    expect(element.querySelectorAll('.line-number').length).toBe(9)
    expect(element.querySelectorAll('.line').length).toBe(9)

    component.refs.scroller.scrollTop = 5 * component.measurements.lineHeight
    await component.getNextUpdatePromise()

    // After scrolling down beyond > 3 rows, the order of line numbers and lines
    // in the DOM is a bit weird because the first tile is recycled to the bottom
    // when it is scrolled out of view
    expect(Array.from(element.querySelectorAll('.line-number')).map(element => element.textContent.trim())).toEqual([
      '10', '11', '12', '4', '5', '6', '7', '8', '9'
    ])
    expect(Array.from(element.querySelectorAll('.line')).map(element => element.textContent)).toEqual([
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

    component.refs.scroller.scrollTop = 2.5 * component.measurements.lineHeight
    await component.getNextUpdatePromise()
    expect(Array.from(element.querySelectorAll('.line-number')).map(element => element.textContent.trim())).toEqual([
      '1', '2', '3', '4', '5', '6', '7', '8', '9'
    ])
    expect(Array.from(element.querySelectorAll('.line')).map(element => element.textContent)).toEqual([
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
    const {component, element, editor} = buildComponent()
    const {scroller} = component.refs

    await editor.update({scrollPastEnd: true})
    await setEditorHeightInLines(component, 6)

    // scroll to end
    scroller.scrollTop = scroller.scrollHeight - scroller.clientHeight
    await component.getNextUpdatePromise()
    expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() - 3)

    editor.update({scrollPastEnd: false})
    await component.getNextUpdatePromise() // wait for scrollable content resize
    await component.getNextUpdatePromise() // wait for async scroll event due to scrollbar shrinking
    expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() - 6)

    // Always allows at least 3 lines worth of overscroll if the editor is short
    await setEditorHeightInLines(component, 2)
    await editor.update({scrollPastEnd: true})
    scroller.scrollTop = scroller.scrollHeight - scroller.clientHeight
    await component.getNextUpdatePromise()
    expect(component.getFirstVisibleRow()).toBe(editor.getScreenLineCount() + 1)
  })

  it('gives the line number gutter an explicit width and height so its layout can be strictly contained', () => {
    const {component, element, editor} = buildComponent({rowsPerTile: 3})

    const gutterElement = element.querySelector('.gutter.line-numbers')
    expect(gutterElement.style.width).toBe(element.querySelector('.line-number').offsetWidth + 'px')
    expect(gutterElement.style.height).toBe(editor.getScreenLineCount() * component.measurements.lineHeight + 'px')
    expect(gutterElement.style.contain).toBe('strict')

    // Tile nodes also have explicit width and height assignment
    expect(gutterElement.firstChild.style.width).toBe(element.querySelector('.line-number').offsetWidth + 'px')
    expect(gutterElement.firstChild.style.height).toBe(3 * component.measurements.lineHeight + 'px')
    expect(gutterElement.firstChild.style.contain).toBe('strict')
  })

  it('translates the gutter so it is always visible when scrolling to the right', async () => {
    const {component, element, editor} = buildComponent({width: 100})

    expect(component.refs.gutterContainer.style.transform).toBe('translateX(0px)')
    component.refs.scroller.scrollLeft = 100
    await component.getNextUpdatePromise()
    expect(component.refs.gutterContainer.style.transform).toBe('translateX(100px)')
  })

  it('renders cursors within the visible row range', async () => {
    const {component, element, editor} = buildComponent({height: 40, rowsPerTile: 2})
    component.refs.scroller.scrollTop = 100
    await component.getNextUpdatePromise()

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

  it('places the hidden input element at the location of the last cursor if it is visible', async () => {
    const {component, element, editor} = buildComponent({height: 60, width: 120, rowsPerTile: 2})
    const {hiddenInput} = component.refs
    component.refs.scroller.scrollTop = 100
    component.refs.scroller.scrollLeft = 40
    await component.getNextUpdatePromise()

    expect(component.getRenderedStartRow()).toBe(4)
    expect(component.getRenderedEndRow()).toBe(12)

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

    expect(getBaseCharacterWidth(component)).toBe(55)
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

    const {scroller} = component.refs
    expect(scroller.clientWidth).toBe(scroller.scrollWidth)
  })

  it('decorates the line numbers of folded lines', async () => {
    const {component, element, editor} = buildComponent()
    editor.foldBufferRow(1)
    await component.getNextUpdatePromise()
    expect(lineNumberNodeForScreenRow(component, 1).classList.contains('folded')).toBe(true)
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
  })

  describe('focus', () => {
    it('focuses the hidden input element and adds the is-focused class when focused', async () => {
      assertDocumentFocused()

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
      assertDocumentFocused()

      const {component, element, editor} = buildComponent()
      const {hiddenInput} = component.refs
      expect(element.classList.contains('is-focused')).toBe(false)
      expect(document.activeElement).not.toBe(hiddenInput)

      hiddenInput.focus()
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(true)
    })

    it('gracefully handles a focus event that occurs prior to the attachedCallback of the element', () => {
      assertDocumentFocused()

      const {component, element, editor} = buildComponent({attach: false})
      const parent = document.createElement('text-editor-component-test-element')
      parent.appendChild(element)
      parent.didAttach = () => element.focus()
      jasmine.attachToDOM(parent)
      expect(document.activeElement).toBe(component.refs.hiddenInput)
    })
  })

  describe('autoscroll on cursor movement', () => {
    it('automatically scrolls vertically when the requested range is within the vertical scroll margin of the top or bottom', async () => {
      const {component, element, editor} = buildComponent({height: 120})
      const {scroller} = component.refs
      expect(component.getLastVisibleRow()).toBe(8)

      editor.scrollToScreenRange([[4, 0], [6, 0]])
      await component.getNextUpdatePromise()
      let scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([8, 0])
      await component.getNextUpdatePromise()
      scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((8 + 1 + editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([3, 0])
      await component.getNextUpdatePromise()
      expect(scroller.scrollTop).toBe((3 - editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([2, 0])
      await component.getNextUpdatePromise()
      expect(scroller.scrollTop).toBe(0)
    })

    it('does not vertically autoscroll by more than half of the visible lines if the editor is shorter than twice the scroll margin', async () => {
      const {component, element, editor} = buildComponent()
      const {scroller} = component.refs
      element.style.height = 5.5 * component.measurements.lineHeight + 'px'
      await component.getNextUpdatePromise()
      expect(component.getLastVisibleRow()).toBe(6)
      const scrollMarginInLines = 2

      editor.scrollToScreenPosition([6, 0])
      await component.getNextUpdatePromise()
      let scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenPosition([6, 4])
      await component.getNextUpdatePromise()
      scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenRange([[4, 4], [6, 4]])
      await component.getNextUpdatePromise()
      expect(scroller.scrollTop).toBe((4 - scrollMarginInLines) * component.measurements.lineHeight)

      editor.scrollToScreenRange([[4, 4], [6, 4]], {reversed: false})
      await component.getNextUpdatePromise()
      expect(scrollBottom).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)
    })

    it('automatically scrolls horizontally when the requested range is within the horizontal scroll margin of the right edge of the gutter or right edge of the screen', async () => {
      const {component, element, editor} = buildComponent()
      const {scroller} = component.refs
      element.style.width =
        component.getGutterContainerWidth() +
        3 * editor.horizontalScrollMargin * component.measurements.baseCharacterWidth + 'px'
      await component.getNextUpdatePromise()

      editor.scrollToScreenRange([[1, 12], [2, 28]])
      await component.getNextUpdatePromise()
      let expectedScrollLeft = Math.floor(
        clientLeftForCharacter(component, 1, 12) -
        lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
        (editor.horizontalScrollMargin * component.measurements.baseCharacterWidth)
      )
      expect(scroller.scrollLeft).toBe(expectedScrollLeft)

      editor.scrollToScreenRange([[1, 12], [2, 28]], {reversed: false})
      await component.getNextUpdatePromise()
      expectedScrollLeft = Math.floor(
        component.getGutterContainerWidth() +
        clientLeftForCharacter(component, 2, 28) -
        lineNodeForScreenRow(component, 2).getBoundingClientRect().left +
        (editor.horizontalScrollMargin * component.measurements.baseCharacterWidth) -
        scroller.clientWidth
      )
      expect(scroller.scrollLeft).toBe(expectedScrollLeft)
    })

    it('does not horizontally autoscroll by more than half of the visible "base-width" characters if the editor is narrower than twice the scroll margin', async () => {
      const {component, element, editor} = buildComponent()
      const {scroller, gutterContainer} = component.refs
      await setEditorWidthInCharacters(component, 1.5 * editor.horizontalScrollMargin)

      const contentWidth = scroller.clientWidth - gutterContainer.offsetWidth
      const contentWidthInCharacters = Math.floor(contentWidth / component.measurements.baseCharacterWidth)
      expect(contentWidthInCharacters).toBe(9)

      editor.scrollToScreenRange([[6, 10], [6, 15]])
      await component.getNextUpdatePromise()
      let expectedScrollLeft = Math.floor(
        clientLeftForCharacter(component, 6, 10) -
        lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
        (4 * component.measurements.baseCharacterWidth)
      )
      expect(scroller.scrollLeft).toBe(expectedScrollLeft)
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
  })

  describe('mouse input', () => {
    describe('on the lines', () => {
      it('positions the cursor on single-click', async () => {
        const {component, element, editor} = buildComponent()
        const {lineHeight} = component.measurements

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

      it('autoscrolls the content when dragging near the edge of the screen', async () => {
        const {component, editor} = buildComponent({width: 200, height: 200})
        const {scroller} = component.refs
        spyOn(component, 'handleMouseDragUntilMouseUp')

        let previousScrollTop = 0
        let previousScrollLeft = 0
        function assertScrolledDownAndRight () {
          expect(scroller.scrollTop).toBeGreaterThan(previousScrollTop)
          previousScrollTop = scroller.scrollTop
          expect(scroller.scrollLeft).toBeGreaterThan(previousScrollLeft)
          previousScrollLeft = scroller.scrollLeft
        }

        function assertScrolledUpAndLeft () {
          expect(scroller.scrollTop).toBeLessThan(previousScrollTop)
          previousScrollTop = scroller.scrollTop
          expect(scroller.scrollLeft).toBeLessThan(previousScrollLeft)
          previousScrollLeft = scroller.scrollLeft
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

        // Don't artificially update scroll measurements beyond the minimum or
        // maximum possible scroll positions
        expect(scroller.scrollTop).toBe(0)
        expect(scroller.scrollLeft).toBe(0)
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        expect(component.measurements.scrollTop).toBe(0)
        expect(scroller.scrollTop).toBe(0)
        expect(component.measurements.scrollLeft).toBe(0)
        expect(scroller.scrollLeft).toBe(0)

        const maxScrollTop = scroller.scrollHeight - scroller.clientHeight
        const maxScrollLeft = scroller.scrollWidth - scroller.clientWidth
        scroller.scrollTop = maxScrollTop
        scroller.scrollLeft = maxScrollLeft
        await component.getNextUpdatePromise()

        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        expect(component.measurements.scrollTop).toBe(maxScrollTop)
        expect(component.measurements.scrollLeft).toBe(maxScrollLeft)
      })
    })

    describe('on the line number gutter', () => {
      it('selects all buffer rows intersecting the clicked screen row when a line number is clicked', async () => {
        const {component, editor} = buildComponent()
        spyOn(component, 'handleMouseDragUntilMouseUp')
        editor.setSoftWrapped(true)
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

      it('autoscrolls the content when dragging near the edge of the screen', async () => {
        const {component, editor} = buildComponent({width: 200, height: 200})
        const {scroller} = component.refs
        spyOn(component, 'handleMouseDragUntilMouseUp')

        let previousScrollTop = 0
        let previousScrollLeft = 0
        function assertScrolledDown () {
          expect(scroller.scrollTop).toBeGreaterThan(previousScrollTop)
          previousScrollTop = scroller.scrollTop
          expect(scroller.scrollLeft).toBe(previousScrollLeft)
          previousScrollLeft = scroller.scrollLeft
        }

        function assertScrolledUp () {
          expect(scroller.scrollTop).toBeLessThan(previousScrollTop)
          previousScrollTop = scroller.scrollTop
          expect(scroller.scrollLeft).toBe(previousScrollLeft)
          previousScrollLeft = scroller.scrollLeft
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
        expect(scroller.scrollTop).toBe(0)
        expect(scroller.scrollLeft).toBe(0)
        didDrag({clientX: component.getGutterContainerWidth() + 1, clientY: 1})
        expect(component.measurements.scrollTop).toBe(0)
        expect(scroller.scrollTop).toBe(0)
        expect(component.measurements.scrollLeft).toBe(0)
        expect(scroller.scrollLeft).toBe(0)

        const maxScrollTop = scroller.scrollHeight - scroller.clientHeight
        const maxScrollLeft = scroller.scrollWidth - scroller.clientWidth
        scroller.scrollTop = maxScrollTop
        scroller.scrollLeft = maxScrollLeft
        await component.getNextUpdatePromise()

        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        didDrag({clientX: 199, clientY: 199})
        expect(component.measurements.scrollTop).toBe(maxScrollTop)
        expect(component.measurements.scrollLeft).toBe(maxScrollLeft)
      })
    })
  })
})

function buildComponent (params = {}) {
  const buffer = new TextBuffer({text: SAMPLE_TEXT})
  const editor = new TextEditor({buffer, mini: params.mini})
  const component = new TextEditorComponent({
    model: editor,
    rowsPerTile: params.rowsPerTile,
    updatedSynchronously: false
  })
  const {element} = component
  element.style.width = params.width ? params.width + 'px' : '800px'
  element.style.height = params.height ? params.height + 'px' : '600px'
  if (params.attach !== false) jasmine.attachToDOM(element)
  return {component, element, editor}
}

function getBaseCharacterWidth (component) {
  return Math.round(
    (component.refs.scroller.clientWidth - component.getGutterContainerWidth()) /
    component.measurements.baseCharacterWidth
  )
}

async function setEditorHeightInLines(component, heightInLines) {
  component.element.style.height = component.measurements.lineHeight * heightInLines + 'px'
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
  return gutterElement.children[tileIndex].children[row - tileStartRow]
}

function lineNodeForScreenRow (component, row) {
  const screenLine = component.getModel().screenLineForScreenRow(row)
  return component.lineNodesByScreenLineId.get(screenLine.id)
}

function textNodesForScreenRow (component, row) {
  const screenLine = component.getModel().screenLineForScreenRow(row)
  return component.textNodesByScreenLineId.get(screenLine.id)
}

function assertDocumentFocused () {
  if (!document.hasFocus()) {
    throw new Error('The document needs to be focused to run this test')
  }
}
