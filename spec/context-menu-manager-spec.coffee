ContextMenuManager = require '../src/context-menu-manager'

describe "ContextMenuManager", ->
  [contextMenu, parent, child, grandchild] = []

  beforeEach ->
    {resourcePath} = atom.getLoadSettings()
    contextMenu = new ContextMenuManager({keymapManager: atom.keymaps})
    contextMenu.initialize({resourcePath})

    parent = document.createElement("div")
    child = document.createElement("div")
    grandchild = document.createElement("div")
    parent.tabIndex = -1
    child.tabIndex = -1
    grandchild.tabIndex = -1
    parent.classList.add('parent')
    child.classList.add('child')
    grandchild.classList.add('grandchild')
    child.appendChild(grandchild)
    parent.appendChild(child)

    document.body.appendChild(parent)

  afterEach ->
    document.body.blur()
    document.body.removeChild(parent)


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

    it "prunes a trailing separator", ->
      contextMenu.add
        '.grandchild': [
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {label: 'B', command: 'b'},
          {type: 'separator'}
        ]

      expect(contextMenu.templateForEvent({target: grandchild}).length).toBe(3)

    it "prunes a leading separator", ->
      contextMenu.add
        '.grandchild': [
          {type: 'separator'},
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {label: 'B', command: 'b'}
        ]

      expect(contextMenu.templateForEvent({target: grandchild}).length).toBe(3)

    it "prunes duplicate separators", ->
      contextMenu.add
        '.grandchild': [
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {type: 'separator'},
          {label: 'B', command: 'b'}
        ]

      expect(contextMenu.templateForEvent({target: grandchild}).length).toBe(3)

    it "prunes all redundant separators", ->
      contextMenu.add
        '.grandchild': [
          {type: 'separator'},
          {type: 'separator'},
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {type: 'separator'},
          {label: 'B', command: 'b'}
          {label: 'C', command: 'c'}
          {type: 'separator'},
          {type: 'separator'},
        ]

      expect(contextMenu.templateForEvent({target: grandchild}).length).toBe(4)

    it "throws an error when the selector is invalid", ->
      addError = null
      try
        contextMenu.add '<>': [{label: 'A', command: 'a'}]
      catch error
        addError = error
      expect(addError.message).toContain('<>')

    it "calls `created` hooks for submenu items", ->
      item = {
        label: 'A',
        command: 'B',
        submenu: [
          {
            label: 'C',
            created: (event) -> @label = 'D',
          }
        ]
      }
      contextMenu.add('.grandchild': [item])

      dispatchedEvent = {target: grandchild}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual(
        [
          label: 'A',
          command: 'B',
          submenu: [
            {
              label: 'D',
            }
          ]
        ])

  describe "::templateForEvent(target)", ->
    [keymaps, item] = []

    beforeEach ->
      keymaps = atom.keymaps.add('source', {
        '.child': {
          'ctrl-a': 'test:my-command',
          'shift-b': 'test:my-other-command'
        }
      })
      item = {
        label: 'My Command',
        command: 'test:my-command',
        submenu: [
          {
            label: 'My Other Command',
            command: 'test:my-other-command',
          }
        ]
      }
      contextMenu.add('.parent': [item])

    afterEach ->
      keymaps.dispose()


    it "adds Electron-style accelerators to items that have keybindings", ->
      child.focus()
      dispatchedEvent = {target: child}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual(
        [
          label: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B',
            }
          ]
        ])

    it "adds accelerators when a parent node has key bindings for a given command", ->
      grandchild.focus()
      dispatchedEvent = {target: grandchild}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual(
        [
          label: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B',
            }
          ]
        ])

    it "does not add accelerators when a child node has key bindings for a given command", ->
      parent.focus()
      dispatchedEvent = {target: parent}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual(
        [
          label: 'My Command',
          command: 'test:my-command',
          submenu: [
            {
              label: 'My Other Command',
              command: 'test:my-other-command',
            }
          ]
        ])

    it "adds accelerators based on focus, not context menu target", ->
      grandchild.focus()
      dispatchedEvent = {target: parent}
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual(
        [
          label: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B',
            }
          ]
        ])
