/** @babel */

import {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise} from './async-spec-helpers'

const TextEditorComponent = require('../src/text-editor-component')
const TextEditor = require('../src/text-editor')
const TextBuffer = require('text-buffer')
const fs = require('fs')
const path = require('path')

const SAMPLE_TEXT = fs.readFileSync(path.join(__dirname, 'fixtures', 'sample.js'), 'utf8')
const NBSP_CHARACTER = '\u00a0'

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
    jasmine.attachToDOM(element)
    return {component, element, editor}
  }

  it('renders lines and line numbers for the visible region', async () => {
    const {component, element, editor} = buildComponent({rowsPerTile: 3})

    // TODO: An extra update is caused by marker layer events being asynchronous,
    // so the cursor getting added triggers an update even though we created
    // the component after this occurred. We should make marker layer events
    // synchronous and batched on the transaction.
    await component.getNextUpdatePromise()

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

    editor.setCursorScreenPosition([0, 0]) // out of view
    editor.addCursorAtScreenPosition([2, 2]) // out of view
    editor.addCursorAtScreenPosition([4, 0]) // line start
    editor.addCursorAtScreenPosition([4, 4]) // at token boundary
    editor.addCursorAtScreenPosition([4, 6]) // within token
    editor.addCursorAtScreenPosition([5, Infinity]) // line end
    editor.addCursorAtScreenPosition([10, 2]) // out of view
    await component.getNextUpdatePromise()

    let cursorNodes = Array.from(element.querySelectorAll('.cursor'))
    expect(cursorNodes.length).toBe(4)
    verifyCursorPosition(component, cursorNodes[0], 4, 0)
    verifyCursorPosition(component, cursorNodes[1], 4, 4)
    verifyCursorPosition(component, cursorNodes[2], 4, 6)
    verifyCursorPosition(component, cursorNodes[3], 5, 30)

    editor.setCursorScreenPosition([8, 11])
    await component.getNextUpdatePromise()

    cursorNodes = Array.from(element.querySelectorAll('.cursor'))
    expect(cursorNodes.length).toBe(1)
    verifyCursorPosition(component, cursorNodes[0], 8, 11)

    editor.setCursorScreenPosition([0, 0])
    await component.getNextUpdatePromise()

    cursorNodes = Array.from(element.querySelectorAll('.cursor'))
    expect(cursorNodes.length).toBe(0)
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
  return component.lineNodesByScreenLine.get(screenLine)
}

function textNodesForScreenRow (component, row) {
  const screenLine = component.getModel().screenLineForScreenRow(row)
  return component.textNodesByScreenLine.get(screenLine)
}
