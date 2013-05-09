fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

describe 'apm command line interface', ->
  beforeEach ->
    spyOn(console, 'log')
    spyOn(console, 'error')
    spyOn(process.stdout, 'write')
    spyOn(process.stderr, 'write')

  describe 'when no arguments are present', ->
    it 'prints a usage message', ->
      apm.run([])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the help flag is specified', ->
    it 'prints a usage message', ->
      apm.run(['-h'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the version flag is specified', ->
    it 'prints the version', ->
      apm.run(['-v'])
      expect(console.error).not.toHaveBeenCalled()
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[0][0]).toBe JSON.parse(fs.readFileSync('package.json')).version

  describe 'when an unrecognized command is specified', ->
    it 'prints an error message', ->
      apm.run(['this-will-never-be-a-command'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'apm install', ->
    atomHome = null

    beforeEach ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome

    describe "when installing a TextMate bundle", ->
      it 'installs the bundle to the atom packages directory', ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', "#{__dirname}/fixtures/make.tmbundle.git"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'packages', 'make.tmbundle', 'Syntaxes', 'Makefile.plist'))).toBeTruthy()

    describe "when installing a node module", ->
      server = null

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

      afterEach ->
        server.close()

      describe 'when a URL to a module is specified', ->
        it 'installs the module at the path', ->
          callback = jasmine.createSpy('callback')
          apm.run(['install', "http://localhost:3000/test-module-1.0.0.tgz"], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount > 0

          runs ->
            expect(fs.existsSync(path.join(atomHome, 'packages', 'test-module', 'index.js'))).toBeTruthy()
            expect(fs.existsSync(path.join(atomHome, 'packages', 'test-module', 'package.json'))).toBeTruthy()

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
