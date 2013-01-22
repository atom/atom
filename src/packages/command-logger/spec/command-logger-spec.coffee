RootView = require 'root-view'
CommandLogger = require 'command-logger/src/command-logger-view'

describe "CommandLogger", ->
  [rootView, commandLogger, editor] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage('command-logger').getInstance()
    editor = rootView.getActiveEditor()
    commandLogger = CommandLogger.instance

  afterEach ->
    rootView.deactivate()

  describe "when a command is triggered", ->
    it "records the number of times the command is triggered", ->
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()
      editor.trigger 'core:backspace'
      expect(commandLogger.eventLog['core:backspace'].count).toBe 1
      editor.trigger 'core:backspace'
      expect(commandLogger.eventLog['core:backspace'].count).toBe 2

    it "records the date the command was last triggered", ->
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()
      editor.trigger 'core:backspace'
      lastRun = commandLogger.eventLog['core:backspace'].lastRun
      expect(lastRun).toBeGreaterThan 0
      start = new Date().getTime()
      waitsFor ->
        new Date().getTime() > start

      runs ->
        editor.trigger 'core:backspace'
        expect(commandLogger.eventLog['core:backspace'].lastRun).toBeGreaterThan lastRun

  describe "when the data is cleared", ->
    it "removes all triggered events from the log", ->
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()
      editor.trigger 'core:backspace'
      expect(commandLogger.eventLog['core:backspace'].count).toBe 1
      rootView.trigger 'command-logger:clear-data'
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()

  describe "when an event is ignored", ->
    it "does not create a node for that event", ->
      commandLogger.ignoredEvents.push 'editor:delete-line'
      editor.trigger 'editor:delete-line'
      nodes = commandLogger.createNodes()
      for node in nodes
        continue unless node.name is 'Editor'
        for child in node.children
          expect(child.name.indexOf('Delete Line')).toBe -1
