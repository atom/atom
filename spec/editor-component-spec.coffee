{React} = require 'reactionary'
EditorComponent = require '../src/editor-component'

describe "EditorComponent", ->
  [editor, component, node, lineHeight] = []

  beforeEach ->
    editor = atom.project.openSync('sample.js')
    container = document.querySelector('#jasmine-content')
    component = React.renderComponent(EditorComponent({editor}), container)
    node = component.getDOMNode()

    fontSize = 20
    lineHeight = 1.3 * fontSize
    node.style.lineHeight = 1.3
    node.style.fontSize = fontSize + 'px'

  it "renders only the currently-visible lines", ->
    node.style.height = 4.5 * lineHeight + 'px'
    component.updateAllDimensions()

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(4).text

    node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeight
    component.onVerticalScroll()

    expect(node.querySelector('.lines').offsetTop).toBe  -2.5 * lineHeight

    lines = node.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text

    spacers = node.querySelectorAll('.spacer')
    expect(spacers[0].offsetHeight).toBe 2 * lineHeight
    expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 7) * lineHeight
