child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe "apm test", ->
  [specPath] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    currentDir = temp.mkdirSync('apm-init-')
    spyOn(process, 'cwd').andReturn(currentDir)
    specPath = path.join(currentDir, 'spec')

  it "calls atom to test", ->
    atomSpawn = spyOn(child_process, 'spawn').andReturn
      stdout:
        on: ->
      stderr:
        on: ->
      on: ->
    apm.run(['test'])

    waitsFor 'waiting for test to complete', ->
      atomSpawn.callCount is 1

    runs ->
      if process.platform is 'win32'
        expect(atomSpawn.mostRecentCall.args[1][2].indexOf('atom')).not.toBe -1
        expect(atomSpawn.mostRecentCall.args[1][2].indexOf('--dev')).not.toBe -1
        expect(atomSpawn.mostRecentCall.args[1][2].indexOf('--test')).not.toBe -1
      else
        expect(atomSpawn.mostRecentCall.args[0]).toEqual 'atom'
        expect(atomSpawn.mostRecentCall.args[1][0]).toEqual '--dev'
        expect(atomSpawn.mostRecentCall.args[1][1]).toEqual '--test'
        expect(atomSpawn.mostRecentCall.args[1][2]).toEqual specPath
        expect(atomSpawn.mostRecentCall.args[2].streaming).toBeTruthy()

  describe 'returning', ->
    [callback] = []

    returnWithCode = (type, code) ->
      callback = jasmine.createSpy('callback')
      atomReturnFn = (e, fn) -> fn(code) if e is type
      spyOn(child_process, 'spawn').andReturn
        stdout:
          on: ->
        stderr:
          on: ->
        on: atomReturnFn
        removeListener: -> # no op
      apm.run(['test'], callback)

    describe 'successfully', ->
      beforeEach -> returnWithCode('close', 0)

      it "prints success", ->
        expect(callback).toHaveBeenCalled()
        expect(callback.mostRecentCall.args[0]).toBeUndefined()
        expect(process.stdout.write.mostRecentCall.args[0]).toEqual 'Tests passed\n'.green

    describe 'with a failure', ->
      beforeEach -> returnWithCode('close', 1)

      it "prints failure", ->
        expect(callback).toHaveBeenCalled()
        expect(callback.mostRecentCall.args[0]).toEqual 'Tests failed'

    describe 'with an error', ->
      beforeEach -> returnWithCode('error')

      it "prints failure", ->
        expect(callback).toHaveBeenCalled()
        expect(callback.mostRecentCall.args[0]).toEqual 'Tests failed'
