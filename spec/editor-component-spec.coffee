{React} = require 'reactionary'
EditorComponent = require '../src/editor-component'

describe "EditorComponent", ->
  [editor, component, node, lineHeight, charWidth] = []

  beforeEach ->
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) -> fn()

    editor = atom.project.openSync('sample.js')
    container = document.querySelector('#jasmine-content')
    component = React.renderComponent(EditorComponent({editor}), container)
    node = component.getDOMNode()

    node.style.lineHeight = 1.3
    node.style.fontSize = '20px'
    {lineHeight, charWidth} = component.measureLineDimensions()

  it "renders only the currently-visible lines", ->
    node.style.height = 4.5 * lineHeight + 'px'
    component.updateAllDimensions()

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(4).text

    node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeight
    component.onVerticalScroll()

    expect(node.querySelector('.scrollable-content').style['-webkit-transform']).toBe "translateY(#{-2.5 * lineHeight}px)"

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text

    spacers = node.querySelectorAll('.spacer')
    expect(spacers[0].offsetHeight).toBe 2 * lineHeight
    expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 7) * lineHeight

  it "renders the currently visible cursors", ->
    cursor1 = editor.getCursor()
    cursor1.setScreenPosition([0, 5])

    node.style.height = 4.5 * lineHeight + 'px'
    component.updateAllDimensions()

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 1
    expect(cursorNodes[0].offsetHeight).toBe lineHeight
    expect(cursorNodes[0].offsetWidth).toBe charWidth
    expect(cursorNodes[0].offsetTop).toBe 0
    expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth

    cursor2 = editor.addCursorAtScreenPosition([6, 11])
    cursor3 = editor.addCursorAtScreenPosition([4, 10])

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 2
    expect(cursorNodes[0].offsetTop).toBe 0
    expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth
    expect(cursorNodes[1].offsetTop).toBe 4 * lineHeight
    expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

    node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeight
    component.onVerticalScroll()

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 2
    expect(cursorNodes[0].offsetTop).toBe 6 * lineHeight
    expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth
    expect(cursorNodes[1].offsetTop).toBe 4 * lineHeight
    expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

    cursor3.destroy()
    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes.length).toBe 1
    expect(cursorNodes[0].offsetTop).toBe 6 * lineHeight
    expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth
