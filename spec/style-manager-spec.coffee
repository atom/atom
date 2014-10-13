StyleManager = require '../src/style-manager'

describe "StyleManager", ->
  manager = null

  beforeEach ->
    manager = new StyleManager

  describe "::addStyleSheet(source, params)", ->
    it "adds a stylesheet based on the given source and returns a disposable allowing it to be removed", ->
      addEvents = []
      removeEvents = []
      manager.onDidAddStyleSheet (event) -> addEvents.push(event)
      manager.onDidRemoveStyleSheet (event) -> removeEvents.push(event)

      disposable = manager.addStyleSheet("a {color: red;}")

      expect(addEvents.length).toBe 1
      expect(addEvents[0].styleElement.textContent).toBe "a {color: red;}"

      styleElements = manager.getStyleElements()
      expect(styleElements.length).toBe 1
      expect(styleElements[0].textContent).toBe "a {color: red;}"

      disposable.dispose()

      expect(removeEvents.length).toBe 1
      expect(removeEvents[0].styleElement.textContent).toBe "a {color: red;}"
      expect(manager.getStyleElements().length).toBe 0
