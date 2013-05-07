fs = require 'fs'
apm = require '../lib/apm-cli'

describe 'apm command line interface', ->
  describe 'when no arguments are present', ->
    it 'prints a usage message', ->
      spyOn(console, 'log').andCallThrough()
      spyOn(console, 'error')
      apm.run([])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the version flag is specified', ->
    it 'prints a usage message', ->
      spyOn(console, 'log').andCallThrough()
      spyOn(console, 'error')
      apm.run(['-h'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the version flag is specified', ->
    it 'prints the version', ->
      spyOn(console, 'log')
      spyOn(console, 'error')
      apm.run(['-v'])
      expect(console.error).not.toHaveBeenCalled()
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[0][0]).toBe JSON.parse(fs.readFileSync('package.json')).version
