RootView = require 'root-view'
CommandLogger = require 'command-logger/lib/command-logger-view'

describe "CommandLogger", ->
  [commandLogger, editor] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    commandLogger = window.loadPackage('command-logger').packageMain
    commandLogger.eventLog = {}
    editor = rootView.getActiveEditor()

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
      commandLoggerView = commandLogger.createView()
      commandLoggerView.ignoredEvents.push 'editor:delete-line'
      editor.trigger 'editor:delete-line'
      commandLoggerView.eventLog = commandLogger.eventLog
      nodes = commandLoggerView.createNodes()
      for node in nodes
        continue unless node.name is 'Editor'
        for child in node.children
          expect(child.name.indexOf('Delete Line')).toBe -1
