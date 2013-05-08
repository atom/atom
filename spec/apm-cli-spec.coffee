fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
apm = require '../lib/apm-cli'

describe 'apm command line interface', ->
  beforeEach ->
    spyOn(process.stdout, 'write')
    spyOn(process.stderr, 'write')

  describe 'when no arguments are present', ->
    it 'prints a usage message', ->
      spyOn(console, 'log')
      spyOn(console, 'error')
      apm.run([])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the version flag is specified', ->
    it 'prints a usage message', ->
      spyOn(console, 'log')
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

  describe 'when an unrecognized command is specified', ->
    it 'prints an error message', ->
      spyOn(console, 'log')
      spyOn(console, 'error')
      apm.run(['this-will-never-be-a-command'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when install is run with a path', ->
    server = null

    beforeEach ->
      app = express()
      app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
      server =  http.createServer(app)
      server.listen(3000)

    afterEach ->
      server.close()

    it 'installs the module', ->
      spyOn(console, 'log')
      spyOn(console, 'error')

      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_NODE_URL = "http://localhost:3000/node"
      modulePath = path.join(__dirname, 'fixtures', 'test-module')
      callback = jasmine.createSpy('callback')
      apm.run(['install', modulePath], callback)

      waitsFor 'waiting for install to complete', 600000, ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', 'node_modules', 'test-module', 'index.js'))).toBeTruthy()
        expect(fs.existsSync(path.join(atomHome, 'packages', 'node_modules', 'test-module', 'package.json'))).toBeTruthy()
