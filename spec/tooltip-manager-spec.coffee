TooltipManager = require '../src/tooltip-manager'
_ = require 'underscore-plus'

describe "TooltipManager", ->
  [manager, element] = []

  ctrlX = _.humanizeKeystroke("ctrl-x")
  ctrlY = _.humanizeKeystroke("ctrl-y")

  beforeEach ->
    manager = new TooltipManager(keymapManager: atom.keymaps)
    element = document.createElement('div')
    element.classList.add('foo')
    jasmine.attachToDOM(element)

  hover = (element, fn) ->
    element.dispatchEvent(new CustomEvent('mouseenter', bubbles: false))
    element.dispatchEvent(new CustomEvent('mouseover', bubbles: true))
    advanceClock(manager.defaults.delay.show)
    fn()
    element.dispatchEvent(new CustomEvent('mouseleave', bubbles: false))
    element.dispatchEvent(new CustomEvent('mouseout', bubbles: true))
    advanceClock(manager.defaults.delay.hide)

  describe "::add(target, options)", ->
    it "creates a tooltip based on the given options when hovering over the target element", ->
      manager.add element, title: "Title"
      hover element, ->
        expect(document.body.querySelector(".tooltip")).toHaveText("Title")

    it "allows jQuery elements to be passed as the target", ->
      element2 = document.createElement('div')
      jasmine.attachToDOM(element2)

      fakeJqueryWrapper = [element, element2]
      fakeJqueryWrapper.jquery = 'any-version'
      disposable = manager.add fakeJqueryWrapper, title: "Title"

      hover element, -> expect(document.body.querySelector(".tooltip")).toHaveText("Title")
      expect(document.body.querySelector(".tooltip")).toBeNull()
      hover element2, -> expect(document.body.querySelector(".tooltip")).toHaveText("Title")
      expect(document.body.querySelector(".tooltip")).toBeNull()

      disposable.dispose()

      hover element, -> expect(document.body.querySelector(".tooltip")).toBeNull()
      hover element2, -> expect(document.body.querySelector(".tooltip")).toBeNull()

    describe "when a selector is specified", ->
      it "creates a tooltip when hovering over a descendant of the target that matches the selector", ->
        child = document.createElement('div')
        child.classList.add('bar')
        grandchild = document.createElement('div')
        element.appendChild(child)
        child.appendChild(grandchild)

        manager.add element, selector: '.bar', title: 'Bar'

        hover grandchild, ->
          expect(document.body.querySelector('.tooltip')).toHaveText('Bar')
        expect(document.body.querySelector('.tooltip')).toBeNull()

    describe "when a keyBindingCommand is specified", ->
      describe "when a title is specified", ->
        it "appends the key binding corresponding to the command to the title", ->
          atom.keymaps.add 'test',
            '.foo': 'ctrl-x ctrl-y': 'test-command'
            '.bar': 'ctrl-x ctrl-z': 'test-command'

          manager.add element, title: "Title", keyBindingCommand: 'test-command'

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "Title #{ctrlX} #{ctrlY}"

      describe "when no title is specified", ->
        it "shows the key binding corresponding to the command alone", ->
          atom.keymaps.add 'test', '.foo': 'ctrl-x ctrl-y': 'test-command'

          manager.add element, keyBindingCommand: 'test-command'

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "#{ctrlX} #{ctrlY}"

      describe "when a keyBindingTarget is specified", ->
        it "looks up the key binding relative to the target", ->
          atom.keymaps.add 'test',
            '.bar': 'ctrl-x ctrl-z': 'test-command'
            '.foo': 'ctrl-x ctrl-y': 'test-command'

          manager.add element, keyBindingCommand: 'test-command', keyBindingTarget: element

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "#{ctrlX} #{ctrlY}"

        it "does not display the keybinding if there is nothing mapped to the specified keyBindingCommand", ->
          manager.add element, title: 'A Title', keyBindingCommand: 'test-command', keyBindingTarget: element

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement.textContent).toBe "A Title"

    describe "when .dispose() is called on the returned disposable", ->
      it "no longer displays the tooltip on hover", ->
        disposable = manager.add element, title: "Title"

        hover element, ->
          expect(document.body.querySelector(".tooltip")).toHaveText("Title")

        disposable.dispose()

        hover element, ->
          expect(document.body.querySelector(".tooltip")).toBeNull()

    describe "when the window is resized", ->
      it "hides the tooltips", ->
        manager.add element, title: "Title"
        hover element, ->
          expect(document.body.querySelector(".tooltip")).toBeDefined()
          window.dispatchEvent(new CustomEvent('resize'))
          expect(document.body.querySelector(".tooltip")).toBeNull()
