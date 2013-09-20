{$$} = require 'atom'

ContextMenuManager = require '../src/context-menu-manager'

describe "ContextMenuManager", ->
  [contextMenu] = []

  beforeEach ->
    contextMenu = new ContextMenuManager

  describe "adding definitions", ->
    it 'loads',  ->
      contextMenu.add 'file-path',
        '.selector':
          'label': 'command'

      expect(contextMenu.definitions['.selector'][0].label).toEqual 'label'
      expect(contextMenu.definitions['.selector'][0].command).toEqual 'command'

    describe 'dev mode', ->
      it 'loads',  ->
        contextMenu.add 'file-path',
          '.selector':
            'label': 'command'
        , devMode: true

        expect(contextMenu.devModeDefinitions['.selector'][0].label).toEqual 'label'
        expect(contextMenu.devModeDefinitions['.selector'][0].command).toEqual 'command'

  describe "building a menu template", ->
    beforeEach ->
      contextMenu.definitions = {
        '.parent':[
          label: 'parent'
          command: 'command-p'
         ]
        '.child': [
          label: 'child'
          command: 'command-c'
        ]
      }

      contextMenu.devModeDefinitions =
        '.parent': [
          label: 'dev-label'
          command: 'dev-command'
        ]

    describe "on a single element", ->
      [element] = []

      beforeEach ->
        element = ($$ -> @div class: 'parent')[0]

      it "creates a menu with a single item", ->
        menu = contextMenu.combinedMenuTemplateForElement(element)

        expect(menu[0].label).toEqual 'parent'
        expect(menu[0].command).toEqual 'command-p'
        expect(menu[1]).toBeUndefined()

      describe "in devMode", ->
        beforeEach -> contextMenu.devMode = true

        it "creates a menu with development items", ->
          menu = contextMenu.combinedMenuTemplateForElement(element)

          expect(menu[0].label).toEqual 'parent'
          expect(menu[0].command).toEqual 'command-p'
          expect(menu[1].type).toEqual 'separator'
          expect(menu[2].label).toEqual 'dev-label'
          expect(menu[2].command).toEqual 'dev-command'


    describe "on multiple elements", ->
      [element] = []

      beforeEach ->
        element = $$ ->
          @div class: 'parent', =>
            @div class: 'child'

        element = element.find('.child')[0]

      it "creates a menu with a two items", ->
        menu = contextMenu.combinedMenuTemplateForElement(element)

        expect(menu[0].label).toEqual 'child'
        expect(menu[0].command).toEqual 'command-c'
        expect(menu[1].label).toEqual 'parent'
        expect(menu[1].command).toEqual 'command-p'
        expect(menu[2]).toBeUndefined()

      describe "in devMode", ->
        beforeEach -> contextMenu.devMode = true

        xit "creates a menu with development items", ->
          menu = contextMenu.combinedMenuTemplateForElement(element)

          expect(menu[0].label).toEqual 'child'
          expect(menu[0].command).toEqual 'command-c'
          expect(menu[1].label).toEqual 'parent'
          expect(menu[1].command).toEqual 'command-p'
          expect(menu[2].label).toEqual 'dev-label'
          expect(menu[2].command).toEqual 'dev-command'
          expect(menu[3]).toBeUndefined()

  describe "#executeBuildHandlers", ->
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

