ChildProcess = require 'child_process'
Spawner = require '../src/main-process/spawner'

describe "Spawner", ->
  [harmlessSpawn] = []

  beforeEach ->
    # Prevent any commands from actually running and affecting the host
    originalSpawn = ChildProcess.spawn

    harmlessSpawn =
      # Just spawn something that won't actually modify the host
      if process.platform is 'win32'
        originalSpawn('dir')
      else
        originalSpawn('ls')

    spyOn(ChildProcess, 'spawn').andCallFake (command, args, callback) ->
      harmlessSpawn

  it "invokes passed callback", ->
    someCallback = jasmine.createSpy('someCallback')

    Spawner.spawn('some-command', 'some-args', someCallback)

    waitsFor ->
      someCallback.callCount is 1

  it "spawns passed command with arguments", ->
    actualCommand = null
    actualArgs = null

    # Redefine fake invocation, so to remember passed arguments
    jasmine.unspy(ChildProcess, 'spawn')
    spyOn(ChildProcess, 'spawn').andCallFake (command, args) ->
      actualCommand = command
      actualArgs = args
      harmlessSpawn

    expectedCommand = 'some-command'
    expectedArgs = 'some-args'
    someCallback = jasmine.createSpy('someCallback')

    Spawner.spawn(expectedCommand, expectedArgs, someCallback)

    expect(actualCommand).toBe expectedCommand
    expect(actualArgs).toBe expectedArgs

  it "ignores errors by spawned process", ->
    # Redefine fake invocation, so to cause an error
    jasmine.unspy(ChildProcess, 'spawn')
    spyOn(ChildProcess, 'spawn').andCallFake -> throw new Error("EBUSY")

    someCallback = jasmine.createSpy('someCallback')

    expect(Spawner.spawn('some-command', 'some-args', someCallback)).toBe undefined

    waitsFor ->
      someCallback.callCount is 1
