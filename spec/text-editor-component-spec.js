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

  function buildComponent (params = {}) {
    const buffer = new TextBuffer({text: SAMPLE_TEXT})
    const editor = new TextEditor({buffer})
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

  describe('focus', () => {
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
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(true)

      document.body.focus()
      expect(document.activeElement).not.toBe(hiddenInput)
      await component.getNextUpdatePromise()
      expect(element.classList.contains('is-focused')).toBe(false)
    })

    it('gracefully handles a focus event that occurs prior to the attachedCallback of the element', () => {
      const {component, element, editor} = buildComponent({attach: false})
      const parent = document.createElement('text-editor-component-test-element')
      parent.appendChild(element)
      parent.didAttach = () => element.focus()
      jasmine.attachToDOM(parent)
      expect(document.activeElement).toBe(component.refs.hiddenInput)
    })
  })

  describe('autoscroll', () => {
    it('automatically scrolls vertically when the cursor is within vertical scroll margin of the top or bottom', async () => {
      const {component, element, editor} = buildComponent({height: 120})
      const {scroller} = component.refs
      expect(component.getLastVisibleRow()).toBe(8)

      editor.setCursorScreenPosition([6, 0])
      await component.getNextUpdatePromise()
      let scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.setCursorScreenPosition([8, 0])
      await component.getNextUpdatePromise()
      scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((8 + 1 + editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.setCursorScreenPosition([3, 0])
      await component.getNextUpdatePromise()
      expect(scroller.scrollTop).toBe((3 - editor.verticalScrollMargin) * component.measurements.lineHeight)

      editor.setCursorScreenPosition([2, 0])
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

      editor.setCursorScreenPosition([6, 0])
      await component.getNextUpdatePromise()
      let scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.setCursorScreenPosition([6, 4])
      await component.getNextUpdatePromise()
      scrollBottom = scroller.scrollTop + scroller.clientHeight
      expect(scrollBottom).toBe((6 + 1 + scrollMarginInLines) * component.measurements.lineHeight)

      editor.setCursorScreenPosition([4, 4])
      await component.getNextUpdatePromise()
      expect(scroller.scrollTop).toBe((4 - scrollMarginInLines) * component.measurements.lineHeight)
    })
  })
})

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

function lineNodeForScreenRow (component, row) {
  const screenLine = component.getModel().screenLineForScreenRow(row)
  return component.lineNodesByScreenLineId.get(screenLine.id)
}

function textNodesForScreenRow (component, row) {
  const screenLine = component.getModel().screenLineForScreenRow(row)
  return component.textNodesByScreenLineId.get(screenLine.id)
}
