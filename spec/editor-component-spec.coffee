{React} = require 'reactionary'
EditorComponent = require '../src/editor-component'

describe "EditorComponent", ->
  [editor, component, node, lineHeight, charWidth] = []

  beforeEach ->
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
    spyOn(window, 'requestAnimationFrame').andCallFake (fn) -> fn()
    component.onVerticalScroll()

    expect(node.querySelector('.scrollable-content').style['-webkit-transform']).toBe "translateY(#{-2.5 * lineHeight}px)"

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text

    spacers = node.querySelectorAll('.spacer')
    expect(spacers[0].offsetHeight).toBe 2 * lineHeight
    expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 7) * lineHeight

  it "renders the currently visible selections", ->
    editor.setCursorScreenPosition([0, 5])

    node.style.height = 4.5 * lineHeight + 'px'
    component.updateAllDimensions()

    cursorNodes = node.querySelectorAll('.cursor')
    expect(cursorNodes[0].offsetHeight).toBe lineHeight
    expect(cursorNodes[0].offsetWidth).toBe charWidth
    expect(cursorNodes[0].offsetTop).toBe 0
    expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth
