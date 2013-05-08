fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
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

  describe 'apm install', ->
    [server, atomHome] = []

    beforeEach ->
      app = express()
      app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
      app.get '/test-module-1.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-1.0.0.tgz')
      server =  http.createServer(app)
      server.listen(3000)

      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_NODE_URL = "http://localhost:3000/node"

      spyOn(console, 'log')
      spyOn(console, 'error')

    afterEach ->
      server.close()

    describe 'when a path is specified', ->
      it 'installs the module at the path', ->
        modulePath = path.join(__dirname, 'fixtures', 'test-module')
        callback = jasmine.createSpy('callback')
        apm.run(['install', modulePath], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'packages', 'node_modules', 'test-module', 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(atomHome, 'packages', 'node_modules', 'test-module', 'package.json'))).toBeTruthy()

    describe 'when no path is specified', ->
      it 'installs all dependent modules', ->
        moduleDirectory = path.join(temp.mkdirSync('apm-test-module-'), 'test-module-with-dependencies')
        wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module-with-dependencies'), moduleDirectory)
        process.chdir(moduleDirectory)
        callback = jasmine.createSpy('callback')
        apm.run(['install'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'package.json'))).toBeTruthy()
