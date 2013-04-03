RootView = require 'root-view'
CommandPanelView = require 'command-panel/lib/command-panel-view'
_ = require 'underscore'

describe "Preview List", ->
  [previewList, commandPanelMain, commandPanelView] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.attachToDom()
    commandPanelMain = atom.activatePackage('command-panel', immediate: true).mainModule
    commandPanelView = commandPanelMain.commandPanelView
    previewList = commandPanelView.previewList
    rootView.trigger 'command-panel:toggle'

  describe "when the list is scrollable", ->
    it "adds more operations to the DOM when `scrollBottom` nears the `pixelOverdraw`", ->
      waitsForPromise ->
        commandPanelView.execute('X x/so/')

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length

        previewList.scrollTop(previewList.pixelOverdraw / 2)
        previewList.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(previewList.prop('scrollHeight')).toBe previousScrollHeight
        expect(previewList.find("li").length).toBe previousOperationCount

        previewList.scrollToBottom()
        previewList.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previousScrollHeight
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount

    it "renders all operations if the preview items are collapsed", ->
      waitsForPromise ->
        commandPanelView.execute('X x/so/')

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length
        previewList.collapseAllPaths()
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount

    it "renders more operations when a preview item is collapsed", ->
      waitsForPromise ->
        commandPanelView.execute('X x/so/')

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length
        previewList.trigger 'command-panel:collapse-result'
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount
