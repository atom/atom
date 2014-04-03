{React} = require 'reactionary'
EditorComponent = require '../src/editor-component'

describe "EditorComponent", ->
  [editor, component, node, lineHeightInPixels, charWidth] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    runs ->
      spyOn(window, 'requestAnimationFrame').andCallFake (fn) -> fn()

      editor = atom.project.openSync('sample.js')
      container = document.querySelector('#jasmine-content')
      component = React.renderComponent(EditorComponent({editor}), container)
      component.setLineHeight(1.3)
      component.setFontSize(20)
      {lineHeightInPixels, charWidth} = component.measureLineDimensions()
      node = component.getDOMNode()

  it "renders only the currently-visible lines", ->
    node.style.height = 4.5 * lineHeightInPixels + 'px'
    component.updateAllDimensions()

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(4).text

    node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
    component.onVerticalScroll()

    expect(node.querySelector('.scrollable-content').style['-webkit-transform']).toBe "translateY(#{-2.5 * lineHeightInPixels}px)"

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text

    spacers = node.querySelectorAll('.spacer')
    expect(spacers[0].offsetHeight).toBe 2 * lineHeightInPixels
    expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 7) * lineHeightInPixels

  it "renders the currently visible cursors", ->
    cursor1 = editor.getCursor()
    cursor1.setScreenPosition([0, 5])

    node.style.height = 4.5 * lineHeightInPixels + 'px'
    component.updateAllDimensions()

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 1
    expect(cursorNodes[0].offsetHeight).toBe lineHeightInPixels
    expect(cursorNodes[0].offsetWidth).toBe charWidth
    expect(cursorNodes[0].offsetTop).toBe 0
    expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth

    cursor2 = editor.addCursorAtScreenPosition([6, 11])
    cursor3 = editor.addCursorAtScreenPosition([4, 10])

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 2
    expect(cursorNodes[0].offsetTop).toBe 0
    expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth
    expect(cursorNodes[1].offsetTop).toBe 4 * lineHeightInPixels
    expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

    node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
    component.onVerticalScroll()

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 2
    expect(cursorNodes[0].offsetTop).toBe 6 * lineHeightInPixels
    expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth
    expect(cursorNodes[1].offsetTop).toBe 4 * lineHeightInPixels
    expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

    cursor3.destroy()
    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 1
    expect(cursorNodes[0].offsetTop).toBe 6 * lineHeightInPixels
    expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth

  it "updates the scroll bar when the scrollTop is changed in the model", ->
    node.style.height = 4.5 * lineHeightInPixels + 'px'
    component.updateAllDimensions()

    scrollbarNode = node.querySelector('.vertical-scrollbar')
    expect(scrollbarNode.scrollTop).toBe 0

    editor.setScrollTop(10)
    expect(scrollbarNode.scrollTop).toBe 10

  it "accounts for character widths when positioning cursors", ->
    atom.config.set('editor.fontFamily', 'sans-serif')
    editor.setCursorScreenPosition([0, 16])

    cursor = node.querySelector('.cursor')
    cursorRect = cursor.getBoundingClientRect()

    cursorLocationTextNode = node.querySelector('.storage.type.function.js').firstChild.firstChild
    range = document.createRange()
    range.setStart(cursorLocationTextNode, 0)
    range.setEnd(cursorLocationTextNode, 1)
    rangeRect = range.getBoundingClientRect()

    expect(cursorRect.left).toBe rangeRect.left
    expect(cursorRect.width).toBe rangeRect.width

  it "transfers focus to the hidden input", ->
    expect(document.activeElement).toBe document.body
    node.focus()
    expect(document.activeElement).toBe node.querySelector('.hidden-input')
