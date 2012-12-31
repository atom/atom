RootView = require 'root-view'
CommandLogger = require 'command-logger'

describe "CommandLogger", ->
  [rootView, commandLogger, editor] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.activatePackage(CommandLogger)
    editor = rootView.getActiveEditor()
    commandLogger = CommandLogger.instance
    rootView.attachToDom()

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
      advanceClock(100)
      editor.trigger 'core:backspace'
      expect(commandLogger.eventLog['core:backspace'].lastRun).toBeGreaterThan lastRun

  describe "when the data is cleared", ->
    it "removes all triggered events from the log", ->
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()
      editor.trigger 'core:backspace'
      expect(commandLogger.eventLog['core:backspace'].count).toBe 1
      rootView.trigger 'command-logger:clear-data'
      expect(commandLogger.eventLog['core:backspace']).toBeUndefined()
