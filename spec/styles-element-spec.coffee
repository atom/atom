StylesElement = require '../src/styles-element'
StyleManager = require '../src/style-manager'

describe "StylesElement", ->
  [element, addedStyleElements, removedStyleElements, updatedStyleElements] = []

  beforeEach ->
    element = new StylesElement
    element.initialize(atom.styles)
    document.querySelector('#jasmine-content').appendChild(element)
    addedStyleElements = []
    removedStyleElements = []
    updatedStyleElements = []
    element.onDidAddStyleElement (element) -> addedStyleElements.push(element)
    element.onDidRemoveStyleElement (element) -> removedStyleElements.push(element)
    element.onDidUpdateStyleElement (element) -> updatedStyleElements.push(element)

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

  it "orders style elements by priority", ->
    initialChildCount = element.children.length

    atom.styles.addStyleSheet("a {color: red}", priority: 1)
    atom.styles.addStyleSheet("a {color: blue}", priority: 0)
    atom.styles.addStyleSheet("a {color: green}", priority: 2)
    atom.styles.addStyleSheet("a {color: yellow}", priority: 1)

    expect(element.children[initialChildCount].textContent).toBe "a {color: blue}"
    expect(element.children[initialChildCount + 1].textContent).toBe "a {color: red}"
    expect(element.children[initialChildCount + 2].textContent).toBe "a {color: yellow}"
    expect(element.children[initialChildCount + 3].textContent).toBe "a {color: green}"

  it "updates existing style nodes when style elements are updated", ->
    initialChildCount = element.children.length

    atom.styles.addStyleSheet("a {color: red;}", sourcePath: '/foo/bar')
    atom.styles.addStyleSheet("a {color: blue;}", sourcePath: '/foo/bar')

    expect(element.children.length).toBe initialChildCount + 1
    expect(element.children[initialChildCount].textContent).toBe "a {color: blue;}"
    expect(updatedStyleElements).toEqual [element.children[initialChildCount]]

  it "only includes style elements matching the 'context' attribute", ->
    initialChildCount = element.children.length

    atom.styles.addStyleSheet("a {color: red;}", context: 'test-context')
    atom.styles.addStyleSheet("a {color: green;}")

    expect(element.children.length).toBe initialChildCount + 2
    expect(element.children[initialChildCount].textContent).toBe "a {color: red;}"
    expect(element.children[initialChildCount + 1].textContent).toBe "a {color: green;}"

    element.setAttribute('context', 'test-context')

    expect(element.children.length).toBe 1
    expect(element.children[0].textContent).toBe "a {color: red;}"

    atom.styles.addStyleSheet("a {color: blue;}", context: 'test-context')
    atom.styles.addStyleSheet("a {color: yellow;}")

    expect(element.children.length).toBe 2
    expect(element.children[0].textContent).toBe "a {color: red;}"
    expect(element.children[1].textContent).toBe "a {color: blue;}"

  describe "atom-text-editor shadow DOM selector upgrades", ->
    beforeEach ->
      spyOn(console, 'warn')

    it "removes the ::shadow pseudo-element from atom-text-editor selectors", ->
      atom.styles.addStyleSheet("""
      atom-text-editor::shadow .class-1, atom-text-editor::shadow .class-2 { color: red; }
      atom-text-editor::shadow > .class-3 { color: yellow; }
      atom-text-editor .class-4 { color: blue; }
      another-element::shadow .class-5 { color: white; }
      """)
      expect(Array.from(element.lastChild.sheet.cssRules).map((r) -> r.selectorText)).toEqual([
        'atom-text-editor .class-1, atom-text-editor .class-2',
        'atom-text-editor > .class-3',
        'atom-text-editor .class-4',
        'another-element::shadow .class-5'
      ])
      expect(console.warn).toHaveBeenCalled()

    describe "when the context of a style sheet is 'atom-text-editor'", ->
      it "prepends `--syntax` to selectors not contained in atom-text-editor or matching a spatial decoration", ->
        atom.styles.addStyleSheet("""
        .class-1 { color: red; }
        .class-2 > .class-3, .class-4.class-5 { color: green; }
        .class-6 atom-text-editor .class-7 { color: yellow; }
        atom-text-editor .class-8, .class-9 { color: blue; }
        atom-text-editor .indent-guide, atom-text-editor .leading-whitespace { background: white; }
        .syntax--class-10 { color: gray; }
        :host .class-11 { color: purple; }
        #id-1 { color: gray; }
        """, {context: 'atom-text-editor'})
        expect(Array.from(element.lastChild.sheet.cssRules).map((r) -> r.selectorText)).toEqual([
          '.syntax--class-1',
          '.syntax--class-2 > .syntax--class-3, .syntax--class-4.syntax--class-5',
          '.class-6 atom-text-editor .class-7',
          'atom-text-editor .class-8, .syntax--class-9',
          'atom-text-editor .syntax--indent-guide, atom-text-editor .syntax--leading-whitespace',
          '.syntax--class-10',
          'atom-text-editor .class-11',
          '#id-1'
        ])
        expect(console.warn).toHaveBeenCalled()

    describe "when the context of a style sheet is not 'atom-text-editor'", ->
      it "never prepends class names with `--syntax`", ->
        atom.styles.addStyleSheet("""
        .class-1 { color: red; }
        .class-2 > .class-3, .class-4.class-5 { color: green; }
        .class-6 atom-text-editor .class-7 { color: yellow; }
        atom-text-editor .class-8, .class-9 { color: blue; }
        atom-text-editor .indent-guide, atom-text-editor .leading-whitespace { background: white; }
        #id-1 { color: gray; }
        """)
        expect(Array.from(element.lastChild.sheet.cssRules).map((r) -> r.selectorText)).toEqual([
          '.class-1'
          '.class-2 > .class-3, .class-4.class-5'
          '.class-6 atom-text-editor .class-7'
          'atom-text-editor .class-8, .class-9'
          'atom-text-editor .indent-guide, atom-text-editor .leading-whitespace'
          '#id-1'
        ])
        expect(console.warn).not.toHaveBeenCalled()

    it "does not throw exceptions on rules with no selectors", ->
      atom.styles.addStyleSheet """
        @media screen {font-size: 10px;}
      """, context: 'atom-text-editor'
