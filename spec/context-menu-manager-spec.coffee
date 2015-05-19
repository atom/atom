{$$} = require '../src/space-pen-extensions'

ContextMenuManager = require '../src/context-menu-manager'

describe "ContextMenuManager", ->
  [contextMenu, parent, child, grandchild] = []

  beforeEach ->
    {resourcePath} = atom.getLoadSettings()
    contextMenu = new ContextMenuManager({resourcePath})

    parent = document.createElement("div")
    child = document.createElement("div")
    grandchild = document.createElement("div")
    parent.classList.add('parent')
    child.classList.add('child')
    grandchild.classList.add('grandchild')
    child.appendChild(grandchild)
    parent.appendChild(child)

  describe "::add(itemsBySelector)", ->
    it "can add top-level menu items that can be removed with the returned disposable", ->
      disposable = contextMenu.add
        '.parent': [{label: 'A', command: 'a'}]
        '.child': [{label: 'B', command: 'b'}]
        '.grandchild': [{label: 'C', command: 'c'}]

      expect(contextMenu.templateForElement(grandchild)).toEqual [
        {label: 'C', command: 'c'}
        {label: 'B', command: 'b'}
        {label: 'A', command: 'a'}
      ]

      disposable.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual []

    it "can add submenu items to existing menus that can be removed with the returned disposable", ->
      disposable1 = contextMenu.add
        '.grandchild': [{label: 'A', submenu: [{label: 'B', command: 'b'}]}]
      disposable2 = contextMenu.add
        '.grandchild': [{label: 'A', submenu: [{label: 'C', command: 'c'}]}]

      expect(contextMenu.templateForElement(grandchild)).toEqual [{
        label: 'A',
        submenu: [
          {label: 'B', command: 'b'}
          {label: 'C', command: 'c'}
        ]
      }]

      disposable2.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{
        label: 'A',
        submenu: [
          {label: 'B', command: 'b'}
        ]
      }]

      disposable1.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual []

    it "favors the most specific / recently added item in the case of a duplicate label", ->
      grandchild.classList.add('foo')

      disposable1 = contextMenu.add
        '.grandchild': [{label: 'A', command: 'a'}]
      disposable2 = contextMenu.add
        '.grandchild.foo': [{label: 'A', command: 'b'}]
      disposable3 = contextMenu.add
        '.grandchild': [{label: 'A', command: 'c'}]
      disposable4 = contextMenu.add
        '.child': [{label: 'A', command: 'd'}]

      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'b'}]

      disposable2.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'c'}]

      disposable3.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'a'}]

      disposable1.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'd'}]

    it "allows multiple separators, but not adjacent to each other", ->
      contextMenu.add
        '.grandchild': [
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {type: 'separator'},
          {label: 'B', command: 'b'},
          {type: 'separator'},
          {type: 'separator'},
          {label: 'C', command: 'c'}
        ]

      expect(contextMenu.templateForElement(grandchild)).toEqual [
        {label: 'A', command: 'a'},
        {type: 'separator'},
        {label: 'B', command: 'b'},
        {type: 'separator'},
        {label: 'C', command: 'c'}
      ]

    it "excludes items marked for display in devMode unless in dev mode", ->
      disposable1 = contextMenu.add
        '.grandchild': [{label: 'A', command: 'a', devMode: true}, {label: 'B', command: 'b', devMode: false}]

      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'B', command: 'b'}]

      contextMenu.devMode = true
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'a'}, {label: 'B', command: 'b'}]

    it "allows items to be associated with `created` hooks which are invoked on template construction with the item and event", ->
      createdEvent = null

      item = {
        label: 'A',
        command: 'a',
        created: (event) ->
          @command = 'b'
          createdEvent = event
      }

      contextMenu.add('.grandchild': [item])

      dispatchedEvent = {target: grandchild}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual [{label: 'A', command: 'b'}]
      expect(item.command).toBe 'a' # doesn't modify original item template
      expect(createdEvent).toBe dispatchedEvent

    it "allows items to be associated with `shouldDisplay` hooks which are invoked on construction to determine whether the item should be included", ->
      shouldDisplayEvent = null
      shouldDisplay = true

      item = {
        label: 'A',
        command: 'a',
        shouldDisplay: (event) ->
          @foo = 'bar'
          shouldDisplayEvent = event
          shouldDisplay
      }
      contextMenu.add('.grandchild': [item])

      dispatchedEvent = {target: grandchild}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual [{label: 'A', command: 'a'}]
      expect(item.foo).toBeUndefined() # doesn't modify original item template
      expect(shouldDisplayEvent).toBe dispatchedEvent

      shouldDisplay = false
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual []

    it "throws an error when the selector is invalid", ->
      addError = null
      try
        contextMenu.add '<>': [{label: 'A', command: 'a'}]
      catch error
        addError = error
      expect(addError.message).toContain('<>')

    describe "when the menus are specified in a legacy format", ->
      beforeEach ->
        jasmine.snapshotDeprecations()

      afterEach ->
        jasmine.restoreDeprecationsSnapshot()

      it "allows items to be specified in the legacy format for now", ->
        contextMenu.add '.parent':
          'A': 'a'
          'Separator 1': '-'
          'B':
            'C': 'c'
            'Separator 2': '-'
            'D': 'd'

        expect(contextMenu.templateForElement(parent)).toEqual [
          {label: 'A', command: 'a'}
          {type: 'separator'}
          {
            label: 'B'
            submenu: [
              {label: 'C', command: 'c'}
              {type: 'separator'}
              {label: 'D', command: 'd'}
            ]
          }
        ]
