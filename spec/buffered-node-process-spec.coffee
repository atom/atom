path = require 'path'
BufferedNodeProcess  = require '../src/buffered-node-process'

describe "BufferedNodeProcess", ->
  it "executes the script in a new process", ->
    exit = jasmine.createSpy('exitCallback')
    output = ''
    stdout = (lines) -> output += lines
    error = ''
    stderr = (lines) -> error += lines
    args = ['hi']
    command = path.join(__dirname, 'fixtures', 'script.js')

    new BufferedNodeProcess({command, args, stdout, stderr, exit})

    waitsFor ->
      exit.callCount is 1

    runs ->
      expect(output).toBe 'hi'
      expect(error).toBe ''
      expect(args).toEqual ['hi']

  it "suppresses deprecations in the new process", ->
    exit = jasmine.createSpy('exitCallback')
    output = ''
    stdout = (lines) -> output += lines
    error = ''
    stderr = (lines) -> error += lines
    command = path.join(__dirname, 'fixtures', 'script-with-deprecations.js')

    new BufferedNodeProcess({command, stdout, stderr, exit})

    waitsFor ->
      exit.callCount is 1

    runs ->
      expect(output).toBe 'hi'
      expect(error).toBe ''
