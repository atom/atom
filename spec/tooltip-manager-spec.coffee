TooltipManager = require '../src/tooltip-manager'
Tooltip = require '../src/tooltip'
_ = require 'underscore-plus'

describe "TooltipManager", ->
  [manager, element] = []

  ctrlX = _.humanizeKeystroke("ctrl-x")
  ctrlY = _.humanizeKeystroke("ctrl-y")

  beforeEach ->
    manager = new TooltipManager(keymapManager: atom.keymaps, viewRegistry: atom.views)
    element = createElement 'foo'

  createElement = (className) ->
    el = document.createElement('div')
    el.classList.add(className)
    jasmine.attachToDOM(el)
    el

  mouseEnter = (element) ->
    element.dispatchEvent(new CustomEvent('mouseenter', bubbles: false))
    element.dispatchEvent(new CustomEvent('mouseover', bubbles: true))

  mouseLeave = (element) ->
    element.dispatchEvent(new CustomEvent('mouseleave', bubbles: false))
    element.dispatchEvent(new CustomEvent('mouseout', bubbles: true))

  hover = (element, fn) ->
    mouseEnter(element)
    advanceClock(manager.hoverDefaults.delay.show)
    fn()
    mouseLeave(element)
    advanceClock(manager.hoverDefaults.delay.hide)

  describe "::add(target, options)", ->
    describe "when the trigger is 'hover' (the default)", ->
      it "creates a tooltip when hovering over the target element", ->
        manager.add element, title: "Title"
        hover element, ->
          expect(document.body.querySelector(".tooltip")).toHaveText("Title")

    describe "when the trigger is 'manual'", ->
      it "creates a tooltip immediately and only hides it on dispose", ->
        disposable = manager.add element, title: "Title", trigger: "manual"
        expect(document.body.querySelector(".tooltip")).toHaveText("Title")
        disposable.dispose()
        expect(document.body.querySelector(".tooltip")).toBeNull()

    describe "when the trigger is 'click'", ->
      it "shows and hides the tooltip when the target element is clicked", ->
        disposable = manager.add element, title: "Title", trigger: "click"
        expect(document.body.querySelector(".tooltip")).toBeNull()
        element.click()
        expect(document.body.querySelector(".tooltip")).not.toBeNull()
        element.click()
        expect(document.body.querySelector(".tooltip")).toBeNull()

        # Hide the tooltip when clicking anywhere but inside the tooltip element
        element.click()
        expect(document.body.querySelector(".tooltip")).not.toBeNull()
        document.body.querySelector(".tooltip").click()
        expect(document.body.querySelector(".tooltip")).not.toBeNull()
        document.body.querySelector(".tooltip").firstChild.click()
        expect(document.body.querySelector(".tooltip")).not.toBeNull()
        document.body.click()
        expect(document.body.querySelector(".tooltip")).toBeNull()

        # Tooltip can show again after hiding due to clicking outside of the tooltip
        element.click()
        expect(document.body.querySelector(".tooltip")).not.toBeNull()
        element.click()
        expect(document.body.querySelector(".tooltip")).toBeNull()

    it "allows a custom item to be specified for the content of the tooltip", ->
      tooltipElement = document.createElement('div')
      manager.add element, item: {element: tooltipElement}
      hover element, ->
        expect(tooltipElement.closest(".tooltip")).not.toBeNull()

    it "allows a custom class to be specified for the tooltip", ->
      tooltipElement = document.createElement('div')
      manager.add element, title: 'Title', class: 'custom-tooltip-class'
      hover element, ->
        expect(document.body.querySelector(".tooltip").classList.contains('custom-tooltip-class')).toBe(true)

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
          expect(document.body.querySelector(".tooltip")).not.toBeNull()
          window.dispatchEvent(new CustomEvent('resize'))
          expect(document.body.querySelector(".tooltip")).toBeNull()

    it "works with follow-through", ->
      element1 = createElement('foo')
      manager.add element1, title: 'Title'
      element2 = createElement('bar')
      manager.add element2, title: 'Title'
      element3 = createElement('baz')
      manager.add element3, title: 'Title'

      hover element1, ->
      expect(document.body.querySelector(".tooltip")).toBeNull()

      mouseEnter(element2)
      expect(document.body.querySelector(".tooltip")).not.toBeNull()
      mouseLeave(element2)
      advanceClock(manager.hoverDefaults.delay.hide)
      expect(document.body.querySelector(".tooltip")).toBeNull()

      advanceClock(Tooltip.FOLLOW_THROUGH_DURATION)
      mouseEnter(element3)
      expect(document.body.querySelector(".tooltip")).toBeNull()
      advanceClock(manager.hoverDefaults.delay.show)
      expect(document.body.querySelector(".tooltip")).not.toBeNull()
