Command = require '../lib/command'

describe "Command", ->
  describe "::spawn", ->
    it "only calls the callback once if the spawned program fails", ->
      exited = false
      callbackCount = 0

      command = new Command
      child = command.spawn "thisisafakecommand", [], ->
        callbackCount++
      child.once "close", ->
        exited = true

      waitsFor ->
        exited

      runs ->
        expect(callbackCount).toEqual 1
