fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
mkdir = require('mkdirp').sync

describe 'apm install', ->
  atomHome = null

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome

  describe "when installing an atom package", ->
    server = null

    beforeEach ->
      app = express()
      app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
      app.get '/node/v0.10.3/node.lib', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node.lib')
      app.get '/node/v0.10.3/x64/node.lib', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node_x64.lib')
      app.get '/tarball/test-module-1.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-1.0.0.tgz')
      app.get '/packages/test-module', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install.json')
      server =  http.createServer(app)
      server.listen(3000)

      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_NODE_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_NODE_VERSION = 'v0.10.3'

    afterEach ->
      server.close()

    describe 'when an invalid URL is specified', ->
      it 'logs an error and exits', ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', "not-a-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
          expect(process.exit.mostRecentCall.args[0]).toBe 1

    describe 'when a module name is specified', ->
      it 'installs the module', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        mkdir(testModuleDirectory)
        existingTestModuleFile = path.join(testModuleDirectory, 'will-be-deleted.js')
        fs.writeFileSync(existingTestModuleFile, '')
        expect(fs.existsSync(existingTestModuleFile)).toBeTruthy()

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(existingTestModuleFile)).toBeFalsy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeUndefined()

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
          expect(callback.mostRecentCall.args[0]).toBeUndefined()

    describe "when the packages directory does not exist", ->
      it "creates the packages directory and any intermediate directories that do not exist", ->
        atomHome = temp.path('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        expect(fs.existsSync(atomHome)).toBe false

        callback = jasmine.createSpy('callback')
        apm.run(['install', 'test-module'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(atomHome)).toBe true
