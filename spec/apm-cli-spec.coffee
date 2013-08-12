fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
config = require '../lib/config'
mkdir = require('mkdirp').sync

describe 'apm command line interface', ->
  beforeEach ->
    spyOn(console, 'log')
    spyOn(console, 'error')
    spyOn(process.stdout, 'write')
    spyOn(process.stderr, 'write')
    spyOn(process, 'exit')

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
    it 'prints an error message and exits', ->
      apm.run(['this-will-never-be-a-command'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0
      expect(process.exit.mostRecentCall.args[0]).toBe 1

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
        process.env.ATOM_NODE_VERSION = 'v0.10.3'

      afterEach ->
        server.close()

      describe 'when an invalid URL is specified', ->
        it 'logs an error and exits', ->
          callback = jasmine.createSpy('callback')
          apm.run(['install', "http://localhost:3000/not-a-module-1.0.0.tgz"], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
            expect(process.exit.mostRecentCall.args[0]).toBe 1

      describe 'when a URL to a module is specified', ->
        it 'installs the module at the path', ->
          testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
          mkdir(testModuleDirectory)
          existingTestModuleFile = path.join(testModuleDirectory, 'will-be-deleted.js')
          fs.writeFileSync(existingTestModuleFile, '')
          expect(fs.existsSync(existingTestModuleFile)).toBeTruthy()

          callback = jasmine.createSpy('callback')
          apm.run(['install', "http://localhost:3000/test-module-1.0.0.tgz"], callback)

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
          apm.run(['install', "http://localhost:3000/test-module-1.0.0.tgz"], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(fs.existsSync(atomHome)).toBe true

  describe 'apm list', ->
    [resourcePath, atomHome] = []

    beforeEach ->
      resourcePath = temp.mkdirSync('apm-resource-path-')
      process.env.ATOM_RESOURCE_PATH = resourcePath
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome

    it 'lists the built-in packages', ->
      packagesPath = path.join(resourcePath, 'src', 'packages')
      mkdir(packagesPath)
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[4][0]).toContain 'test-module@1.0.0'

    it 'lists the packages included in node_modules with an atom engine specified', ->
      packagesPath = path.join(resourcePath, 'node_modules')
      mkdir(packagesPath)
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[4][0]).toContain 'test-module@1.0.0'

    it 'includes vendored packages', ->
      packagesPath = path.join(resourcePath, 'vendor', 'packages')
      mkdir(packagesPath)
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[4][0]).toContain 'test-module@1.0.0'

    it 'lists the installed packages', ->
      packagesPath = path.join(atomHome, 'packages')
      mkdir(packagesPath)
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'test-module@1.0.0'

    it 'labels disabled packages', ->
      packagesPath = path.join(atomHome, 'packages')
      mkdir(packagesPath)
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))
      configPath = path.join(atomHome, 'config.cson')
      fs.writeFileSync(configPath, 'core: disabledPackages: ["test-module"]')

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'test-module@1.0.0 (disabled)'

    it 'includes TextMate bundles', ->
      packagesPath = path.join(atomHome, 'packages')
      mkdir(path.join(packagesPath, 'make.tmbundle'))

      apm.run(['list'])
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'make.tmbundle'

  describe 'apm available', ->
    server = null

    beforeEach ->
      app = express()
      app.get '/available', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'available.json')
      server =  http.createServer(app)
      server.listen(3000)

      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/available"

    afterEach ->
      server.close()

    it 'lists the available packages', ->
      callback = jasmine.createSpy('callback')
      apm.run(['available'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.log).toHaveBeenCalled()
        expect(console.log.argsForCall[1][0]).toContain 'beverly-hills@9.0.2.1.0'

  describe 'apm uninstall', ->
    describe 'when no package is specified', ->
      it 'logs an error and exits', ->
        callback = jasmine.createSpy('callback')
        apm.run(['uninstall'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
          expect(process.exit.mostRecentCall.args[0]).toBe 1

    describe 'when the package is not installed', ->
      it 'logs an error and exits', ->
        callback = jasmine.createSpy('callback')
        apm.run(['uninstall', 'a-package-that-does-not-exist'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
          expect(process.exit.mostRecentCall.args[0]).toBe 1

    describe 'when the package is installed', ->
      it 'deletes the package', ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        packagePath = path.join(atomHome, 'packages', 'test-package')
        mkdir(path.join(packagePath, 'lib'))
        fs.writeFileSync(path.join(packagePath, 'package.json'), "{}")
        process.env.ATOM_HOME = atomHome

        expect(fs.existsSync(packagePath)).toBeTruthy()
        callback = jasmine.createSpy('callback')
        apm.run(['uninstall', 'test-package'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(packagePath)).toBeFalsy()

  describe 'apm update', ->
    [moduleDirectory, server] = []

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
      process.env.ATOM_NODE_VERSION = 'v0.10.3'

      moduleDirectory = path.join(temp.mkdirSync('apm-test-module-'), 'test-module-with-dependencies')
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module-with-dependencies'), moduleDirectory)
      process.chdir(moduleDirectory)

    afterEach ->
      server.close()

    it 'uninstalls any packages not referenced in the package.json and installs any missing packages', ->
      removedPath = path.join(moduleDirectory, 'node_modules', 'will-be-removed')
      mkdir removedPath

      callback = jasmine.createSpy('callback')
      apm.run(['update'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(removedPath)).toBeFalsy()
        expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'index.js'))).toBeTruthy()
        expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'package.json'))).toBeTruthy()
