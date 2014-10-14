StylesElement = require '../src/styles-element'
StyleManager = require '../src/style-manager'

describe "StylesElement", ->
  [element, addedStyleElements, removedStyleElements] = []

  beforeEach ->
    element = new StylesElement
    document.querySelector('#jasmine-content').appendChild(element)
    addedStyleElements = []
    removedStyleElements = []
    element.onDidAddStyleElement (element) -> addedStyleElements.push(element)
    element.onDidRemoveStyleElement (element) -> removedStyleElements.push(element)

  it "renders a style tag for all currently active stylesheets in the style manager", ->
    initialChildCount = element.children.length

    disposable1 = atom.styles.addStyleSheet("a {color: red;}")
    expect(element.children.length).toBe initialChildCount + 1
    expect(element.children[initialChildCount].textContent).toBe "a {color: red;}"
    expect(addedStyleElements).toEqual [element.children[initialChildCount]]

    disposable2 = atom.styles.addStyleSheet("a {color: blue;}")
    expect(element.children.length).toBe initialChildCount + 2
    expect(element.children[initialChildCount + 1].textContent).toBe "a {color: blue;}"
    expect(addedStyleElements).toEqual [element.children[initialChildCount], element.children[initialChildCount + 1]]

    disposable1.dispose()
    expect(element.children.length).toBe initialChildCount + 1
    expect(element.children[initialChildCount].textContent).toBe "a {color: blue;}"
    expect(removedStyleElements).toEqual [addedStyleElements[0]]

  it "orders style elements by group", ->
    initialChildCount = element.children.length

    atom.styles.addStyleSheet("a {color: red}", group: 'a')
    atom.styles.addStyleSheet("a {color: blue}", group: 'b')
    atom.styles.addStyleSheet("a {color: green}", group: 'a')

    expect(element.children[initialChildCount].textContent).toBe "a {color: red}"
    expect(element.children[initialChildCount + 1].textContent).toBe "a {color: green}"
    expect(element.children[initialChildCount + 2].textContent).toBe "a {color: blue}"
