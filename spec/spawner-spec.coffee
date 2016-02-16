ChildProcess = require 'child_process'
Spawner = require '../src/browser/spawner'

describe "Spawner", ->
  beforeEach ->
    # Prevent any commands from actually running and affecting the host
    originalSpawn = ChildProcess.spawn

    spyOn(ChildProcess, 'spawn').andCallFake (command, args) ->
      # Just spawn something that won't actually modify the host
      if process.platform is 'win32'
        originalSpawn('dir')
      else
        originalSpawn('ls')

  it "ignores errors by spawned process", ->
    jasmine.unspy(ChildProcess, 'spawn')
    spyOn(ChildProcess, 'spawn').andCallFake -> throw new Error("EBUSY")

    someCallback = jasmine.createSpy('someCallback')

    expect(Spawner.spawn('some-command', 'some-args', someCallback)).toBe undefined

    waitsFor ->
      someCallback.callCount is 1
