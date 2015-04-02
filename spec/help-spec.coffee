apm = require '../lib/apm-cli'

describe 'command help', ->
  beforeEach ->
    spyOnToken()
    silenceOutput()

  describe "apm help publish", ->
    it "displays the help for the command", ->
      callback = jasmine.createSpy('callback')
      apm.run(['help', 'publish'], callback)

      waitsFor 'waiting for help to complete', 60000, ->
        callback.callCount is 1

      runs ->
        expect(console.error.callCount).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).toBeUndefined()

  describe "apm publish -h", ->
    it "displays the help for the command", ->
      callback = jasmine.createSpy('callback')
      apm.run(['publish', '-h'], callback)

      waitsFor 'waiting for help to complete', 60000, ->
        callback.callCount is 1

      runs ->
        expect(console.error.callCount).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).toBeUndefined()

  describe "apm help", ->
    it "displays the help for apm", ->
      callback = jasmine.createSpy('callback')
      apm.run(['help'], callback)

      waitsFor 'waiting for help to complete', 60000, ->
        callback.callCount is 1

      runs ->
        expect(console.error.callCount).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).toBeUndefined()

  describe "apm", ->
    it "displays the help for apm", ->
      callback = jasmine.createSpy('callback')
      apm.run([], callback)

      waitsFor 'waiting for help to complete', 60000, ->
        callback.callCount is 1

      runs ->
        expect(console.error.callCount).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).toBeUndefined()
