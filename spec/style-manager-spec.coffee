StyleManager = require '../src/style-manager'

describe "StyleManager", ->
  [manager, addEvents, removeEvents, updateEvents] = []

  beforeEach ->
    manager = new StyleManager
    addEvents = []
    removeEvents = []
    updateEvents = []

    manager.onDidAddStyleElement (event) -> addEvents.push(event)
    manager.onDidRemoveStyleElement (event) -> removeEvents.push(event)
    manager.onDidUpdateStyleElement (event) -> updateEvents.push(event)

  describe "::addStyleSheet(source, params)", ->
    it "adds a stylesheet based on the given source and returns a disposable allowing it to be removed", ->
      disposable = manager.addStyleSheet("a {color: red;}")

      expect(addEvents.length).toBe 1
      expect(addEvents[0].textContent).toBe "a {color: red;}"

      styleElements = manager.getStyleElements()
      expect(styleElements.length).toBe 1
      expect(styleElements[0].textContent).toBe "a {color: red;}"

      disposable.dispose()

      expect(removeEvents.length).toBe 1
      expect(removeEvents[0].textContent).toBe "a {color: red;}"
      expect(manager.getStyleElements().length).toBe 0

    describe "when a sourcePath parameter is specified", ->
      it "ensures a maximum of one style element for the given source path, updating a previous if it exists", ->
        disposable1 = manager.addStyleSheet("a {color: red;}", sourcePath: '/foo/bar')

        expect(addEvents.length).toBe 1
        expect(addEvents[0].getAttribute('source-path')).toBe '/foo/bar'

        disposable2 = manager.addStyleSheet("a {color: blue;}", sourcePath: '/foo/bar')

        expect(addEvents.length).toBe 1
        expect(updateEvents.length).toBe 1
        expect(updateEvents[0].getAttribute('source-path')).toBe '/foo/bar'
        expect(updateEvents[0].textContent).toBe "a {color: blue;}"

        disposable2.dispose()
        addEvents = []

        manager.addStyleSheet("a {color: yellow;}", sourcePath: '/foo/bar')

        expect(addEvents.length).toBe 1
        expect(addEvents[0].getAttribute('source-path')).toBe '/foo/bar'
        expect(addEvents[0].textContent).toBe "a {color: yellow;}"

    describe "when a group parameter is specified", ->
      it "inserts the stylesheet at the end of any existing stylesheets for the same group", ->
        manager.addStyleSheet("a {color: red}", group: 'a')
        manager.addStyleSheet("a {color: blue}", group: 'b')
        manager.addStyleSheet("a {color: green}", group: 'a')

        expect(manager.getStyleElements().map (elt) -> elt.textContent).toEqual [
          "a {color: red}"
          "a {color: green}"
          "a {color: blue}"
        ]
