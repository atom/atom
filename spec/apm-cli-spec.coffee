child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
auth = require '../lib/auth'
config = require '../lib/config'
mkdir = require('mkdirp').sync

describe 'apm command line interface', ->
  beforeEach ->
    spyOn(auth, 'getToken').andCallFake (callback) -> callback(null, 'token')
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

    describe "when installing an atom package", ->
      server = null

      beforeEach ->
        app = express()
        app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
          response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
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

      describe 'when a URL to a module is specified', ->
        it 'installs the module at the path', ->
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
      app.get '/tarball/test-module-1.0.0.tgz', (request, response) ->
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

  describe 'apm link/unlink', ->
    describe "when the dev flag is false (the default)", ->
      it 'symlinks packages to $ATOM_HOME/packages', ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        packageToLink = temp.mkdirSync('a-package-')
        process.chdir(packageToLink)
        callback = jasmine.createSpy('callback')

        runs ->
          apm.run(['link'], callback)

        waitsFor 'waiting for link to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeTruthy()
          expect(fs.realpathSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBe fs.realpathSync(packageToLink)
          callback.reset()

        runs ->
          apm.run(['unlink'], callback)

        waitsFor 'waiting for unlink to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeFalsy()

    describe "when the dev flag is true", ->
      it 'symlinks packages to $ATOM_HOME/dev/packages', ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        packageToLink = temp.mkdirSync('a-package-')
        process.chdir(packageToLink)
        callback = jasmine.createSpy('callback')

        runs ->
          apm.run(['link', '--dev'], callback)

        waitsFor 'waiting for link to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeTruthy()
          expect(fs.realpathSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBe fs.realpathSync(packageToLink)
          callback.reset()

        runs ->
          apm.run(['unlink', '--dev'], callback)

        waitsFor 'waiting for unlink to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeFalsy()

    describe "when the hard flag is true", ->
      it "unlinks the package from both $ATOM_HOME/packages and $ATOM_HOME/dev/packages", ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        packageToLink = temp.mkdirSync('a-package-')
        process.chdir(packageToLink)
        callback = jasmine.createSpy('callback')

        runs ->
          apm.run(['link', '--dev'], callback)

        waitsFor 'link --dev to complete', ->
          callback.callCount is 1

        runs ->
          apm.run(['link'], callback)

        waitsFor 'link to complete', ->
          callback.callCount is 2

        runs ->
          apm.run(['unlink', '--hard'], callback)

        waitsFor 'unlink --hard to complete', ->
          callback.callCount is 3

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeFalsy()
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeFalsy()

    describe "when the all flag is true", ->
      it "unlinks all packages in $ATOM_HOME/packages and $ATOM_HOME/dev/packages", ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        packageToLink1 = temp.mkdirSync('a-package-')
        packageToLink2 = temp.mkdirSync('a-package-')
        packageToLink3 = temp.mkdirSync('a-package-')
        callback = jasmine.createSpy('callback')

        runs ->
          apm.run(['link', '--dev', packageToLink1], callback)

        waitsFor 'link --dev to complete', ->
          callback.callCount is 1

        runs ->
          callback.reset()
          apm.run(['link', packageToLink2], callback)
          apm.run(['link', packageToLink3], callback)

        waitsFor 'link to complee', ->
          callback.callCount is 2

        runs ->
          callback.reset()
          expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink1)))).toBeTruthy()
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink2)))).toBeTruthy()
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink3)))).toBeTruthy()
          apm.run(['unlink', '--all'], callback)

        waitsFor 'unlink --all to complete', ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink1)))).toBeFalsy()
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink2)))).toBeFalsy()
          expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink3)))).toBeFalsy()

  describe "apm develop", ->
    [repoPath, linkedRepoPath] = []

    beforeEach ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome

      atomReposHome = temp.mkdirSync('apm-repos-home-dir-')
      process.env.ATOM_REPOS_HOME = atomReposHome

      repoPath = path.join(atomReposHome, 'fake-package')
      linkedRepoPath = path.join(atomHome, 'dev', 'packages', 'fake-package')

    describe "when the package doesn't have a published repository url", ->
      it "logs an error", ->
        Developer = require '../lib/developer'
        spyOn(Developer.prototype, "getRepositoryUrl").andCallFake (packageName, callback) ->
          callback("Here is the error")

        callback = jasmine.createSpy('callback')
        apm.run(['develop', "fake-package"], callback)

        waitsFor 'waiting for develop to complete', ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).toBe "Here is the error"
          expect(fs.existsSync(repoPath)).toBeFalsy()
          expect(fs.existsSync(linkedRepoPath)).toBeFalsy()

    describe "when the repository hasn't been cloned", ->
      it "clones the repository to ATOM_REPOS_HOME and links it to ATOM_HOME/dev/packages", ->
        Developer = require '../lib/developer'
        spyOn(Developer.prototype, "getRepositoryUrl").andCallFake (packageName, callback) ->
          repoUrl = path.join(__dirname, 'fixtures', 'make.tmbundle.git')
          callback(null, repoUrl)

        callback = jasmine.createSpy('callback')
        apm.run(['develop', "fake-package"], callback)

        waitsFor 'waiting for develop to complete', ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).toBeFalsy()
          expect(fs.existsSync(repoPath)).toBeTruthy()
          expect(fs.existsSync(path.join(repoPath, 'Syntaxes', 'Makefile.plist'))).toBeTruthy()
          expect(fs.existsSync(linkedRepoPath)).toBeTruthy()
          expect(fs.realpathSync(linkedRepoPath)).toBe fs.realpathSync(repoPath)

    describe "when the repository has already been cloned", ->
      it "links it to ATOM_HOME/dev/packages", ->
        mkdir(repoPath)
        fs.writeFileSync(path.join(repoPath, "package.json"), "")
        callback = jasmine.createSpy('callback')
        apm.run(['develop', "fake-package"], callback)

        waitsFor 'waiting for develop to complete', ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).toBeFalsy()
          expect(fs.existsSync(repoPath)).toBeTruthy()
          expect(fs.existsSync(linkedRepoPath)).toBeTruthy()
          expect(fs.realpathSync(linkedRepoPath)).toBe fs.realpathSync(repoPath)

  describe "apm init", ->
    [packagePath, themePath] = []

    beforeEach ->
      currentDir = temp.mkdirSync('apm-init-')
      spyOn(process, 'cwd').andReturn(currentDir)
      packagePath = path.join(currentDir, 'fake-package')
      themePath = path.join(currentDir, 'fake-theme')

    describe "when creating a package", ->
      it "generates the proper file structure", ->
        callback = jasmine.createSpy('callback')
        apm.run(['init', '--package', 'fake-package'], callback)

        waitsFor 'waiting for init to complete', ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(packagePath)).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'keymaps'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'keymaps', 'fake-package.cson'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'lib'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package-view.coffee'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package.coffee'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'menus'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'menus', 'fake-package.cson'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-view-spec.coffee'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-spec.coffee'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'stylesheets', 'fake-package.less'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'package.json'))).toBeTruthy()

    describe "when creating a theme", ->
      it "generates the proper file structure", ->
        callback = jasmine.createSpy('callback')
        apm.run(['init', '--theme', 'fake-theme'], callback)

        waitsFor 'waiting for init to complete', ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(themePath)).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'stylesheets', 'base.less'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'index.less'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'package.json'))).toBeTruthy()

  describe "apm test", ->
    [specPath] = []

    beforeEach ->
      currentDir = temp.mkdirSync('apm-init-')
      spyOn(process, 'cwd').andReturn(currentDir)
      specPath = path.join(currentDir, 'spec')

    it "calls atom to test", ->
      atomSpawn = spyOn(child_process, 'spawn').andReturn({ stdout: { on: -> }, stderr: { on: -> }, on: -> })
      apm.run(['test'])

      waitsFor 'waiting for test to complete', ->
        atomSpawn.callCount is 1

      runs ->
        expect(atomSpawn.mostRecentCall.args[0]).toEqual 'atom'
        expect(atomSpawn.mostRecentCall.args[1][0]).toEqual '-d'
        expect(atomSpawn.mostRecentCall.args[1][1]).toEqual '-t'
        expect(atomSpawn.mostRecentCall.args[1][2]).toEqual "--spec-directory=#{specPath}"
        expect(atomSpawn.mostRecentCall.args[2].streaming).toBeTruthy()

    describe 'returning', ->
      [callback] = []

      returnWithCode = (type, code) ->
        callback = jasmine.createSpy('callback')
        atomReturnFn = (e, fn) -> fn(code) if e == type
        spyOn(child_process, 'spawn').andReturn({ stdout: { on: -> }, stderr: { on: -> }, on: atomReturnFn })
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
          expect(callback.mostRecentCall.args[0]).toEqual 'Tests failed'.red

      describe 'with an error', ->
        beforeEach -> returnWithCode('error')

        it "prints failure", ->
          expect(callback).toHaveBeenCalled()
          expect(callback.mostRecentCall.args[0]).toEqual 'Tests failed'.red
