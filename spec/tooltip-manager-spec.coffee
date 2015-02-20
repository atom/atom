TooltipManager = require '../src/tooltip-manager'
{$} = require '../src/space-pen-extensions'

describe "TooltipManager", ->
  [manager, element] = []

  beforeEach ->
    manager = new TooltipManager
    element = document.createElement('div')
    element.classList.add('foo')
    jasmine.attachToDOM(element)

  hover = (element, fn) ->
    $(element).trigger 'mouseenter'
    advanceClock(manager.defaults.delay.show)
    fn()
    $(element).trigger 'mouseleave'
    advanceClock(manager.defaults.delay.hide)

  describe "::add(target, options)", ->
    describe "when the target is an element", ->
      it "creates a tooltip based on the given options when hovering over the target element", ->
        manager.add element, title: "Title"
        hover element, ->
          expect(document.body.querySelector(".tooltip")).toHaveText("Title")

    describe "when a keyBindingCommand is specified", ->
      describe "when a title is specified", ->
        it "appends the key binding corresponding to the command to the title", ->
          atom.keymaps.add 'test',
            '.foo': 'ctrl-x ctrl-y': 'test-command'
            '.bar': 'ctrl-x ctrl-z': 'test-command'

          manager.add element, title: "Title", keyBindingCommand: 'test-command'

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "Title ⌃X ⌃Y"

      describe "when no title is specified", ->
        it "shows the key binding corresponding to the command alone", ->
          atom.keymaps.add 'test', '.foo': 'ctrl-x ctrl-y': 'test-command'

          manager.add element, keyBindingCommand: 'test-command'

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "⌃X ⌃Y"

      describe "when a keyBindingTarget is specified", ->
        it "looks up the key binding relative to the target", ->
          atom.keymaps.add 'test',
            '.bar': 'ctrl-x ctrl-z': 'test-command'
            '.foo': 'ctrl-x ctrl-y': 'test-command'

          manager.add element, keyBindingCommand: 'test-command', keyBindingTarget: element

          hover element, ->
            tooltipElement = document.body.querySelector(".tooltip")
            expect(tooltipElement).toHaveText "⌃X ⌃Y"

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
