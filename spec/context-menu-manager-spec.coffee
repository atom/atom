{$$} = require 'atom'

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
          {label: 'C', command: 'c'}
          {label: 'B', command: 'b'}
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

      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'b'}]

      disposable2.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'c'}]

      disposable3.dispose()
      expect(contextMenu.templateForElement(grandchild)).toEqual [{label: 'A', command: 'a'}]

    it "allows multiple separators", ->
      contextMenu.add
        '.grandchild': [
          {label: 'A', command: 'a'},
          {type: 'separator'},
          {label: 'B', command: 'b'},
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

  describe "executeBuildHandlers", ->
    menuTemplate = [
        label: 'label'
        executeAtBuild: ->
      ]
    event =
      target: null

    it 'should invoke the executeAtBuild fn', ->
      buildFn = spyOn(menuTemplate[0], 'executeAtBuild')
      contextMenu.executeBuildHandlers(event, menuTemplate)

      expect(buildFn).toHaveBeenCalled()
      expect(buildFn.mostRecentCall.args[0]).toBe event
