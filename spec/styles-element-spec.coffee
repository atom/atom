StylesElement = require '../src/styles-element'
StyleManager = require '../src/style-manager'

describe "StylesElement", ->
  element = null

  beforeEach ->
    element = new StylesElement
    document.querySelector('#jasmine-content').appendChild(element)

  it "renders a style tag for all currently active stylesheets in the style manager", ->
    expect(element.children.length).toBe 0

    disposable1 = atom.styles.addStyleSheet("a {color: red;}")
    expect(element.children.length).toBe 1
    expect(element.children[0].textContent).toBe "a {color: red;}"

    disposable2 = atom.styles.addStyleSheet("a {color: blue;}")
    expect(element.children.length).toBe 2
    expect(element.children[1].textContent).toBe "a {color: blue;}"

    disposable1.dispose()
    expect(element.children.length).toBe 1
    expect(element.children[0].textContent).toBe "a {color: blue;}"

  it "orders style elements by group", ->
    expect(element.children.length).toBe 0

    atom.styles.addStyleSheet("a {color: red}", group: 'a')
    atom.styles.addStyleSheet("a {color: blue}", group: 'b')
    atom.styles.addStyleSheet("a {color: green}", group: 'a')

    expect(element.children[0].textContent).toBe "a {color: red}"
    expect(element.children[1].textContent).toBe "a {color: green}"
    expect(element.children[2].textContent).toBe "a {color: blue}"
