path = require 'path'
CSON = require 'season'
fs = require '../lib/fs'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
Install = require '../lib/install'

describe 'apm install', ->
  [atomHome, resourcePath] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome

    # Make sure the cache used is the one for the test env
    delete process.env.npm_config_cache

    resourcePath = temp.mkdirSync('atom-resource-path-')
    process.env.ATOM_RESOURCE_PATH = resourcePath

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
      app.get '/node/v0.10.3/SHASUMS256.txt', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'SHASUMS256.txt')
      app.get '/tarball/test-module-1.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-1.0.0.tgz')
      app.get '/tarball/test-module2-2.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module2-2.0.0.tgz')
      app.get '/packages/test-module', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module.json')
      app.get '/packages/test-module2', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module2.json')
      app.get '/packages/test-module-with-bin', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module-with-bin.json')
      app.get '/packages/test-module-with-symlink', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module-with-symlink.json')
      app.get '/tarball/test-module-with-symlink-5.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-with-symlink-5.0.0.tgz')
      app.get '/tarball/test-module-with-bin-2.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-with-bin-2.0.0.tgz')
      app.get '/packages/multi-module', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-multi-version.json')
      app.get '/packages/atom-2048', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'atom-2048.json')

      server =  http.createServer(app)
      server.listen(3000)

      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_ELECTRON_VERSION = 'v0.10.3'

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
          expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

    describe 'when a package name is specified', ->
      it 'installs the package', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        fs.makeTreeSync(testModuleDirectory)
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
          expect(callback.mostRecentCall.args[0]).toBeNull()

      describe "when the package is already in the cache", ->
        it "installs it from the cache", ->
          cachePath = path.join(require('../lib/apm').getCacheDirectory(), 'test-module2', '2.0.0', 'package.tgz')
          testModuleDirectory = path.join(atomHome, 'packages', 'test-module2')

          callback = jasmine.createSpy('callback')
          apm.run(['install', "test-module2"], callback)
          expect(fs.isFileSync(cachePath)).toBeFalsy()

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
            expect(callback.mostRecentCall.args[0]).toBeNull()
            expect(fs.isFileSync(cachePath)).toBeTruthy()

            callback.reset()
            fs.removeSync(path.join(testModuleDirectory, 'package.json'))
            apm.run(['install', "test-module2"], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
            expect(callback.mostRecentCall.args[0]).toBeNull()
            expect(fs.isFileSync(cachePath)).toBeTruthy()

      describe 'when multiple releases are available', ->
        it 'installs the latest compatible version', ->
          CSON.writeFileSync(path.join(resourcePath, 'package.json'), version: '1.5.0')
          packageDirectory = path.join(atomHome, 'packages', 'test-module')

          callback = jasmine.createSpy('callback')
          apm.run(['install', 'multi-module'], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(JSON.parse(fs.readFileSync(path.join(packageDirectory, 'package.json'))).version).toBe "1.0.0"
            expect(callback.mostRecentCall.args[0]).toBeNull()

        it "ignores the commit SHA suffix in the version", ->
          CSON.writeFileSync(path.join(resourcePath, 'package.json'), version: '1.5.0-deadbeef')
          packageDirectory = path.join(atomHome, 'packages', 'test-module')

          callback = jasmine.createSpy('callback')
          apm.run(['install', 'multi-module'], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(JSON.parse(fs.readFileSync(path.join(packageDirectory, 'package.json'))).version).toBe "1.0.0"
            expect(callback.mostRecentCall.args[0]).toBeNull()

        it 'logs an error when no compatible versions are available', ->
          CSON.writeFileSync(path.join(resourcePath, 'package.json'), version: '0.9.0')
          packageDirectory = path.join(atomHome, 'packages', 'test-module')

          callback = jasmine.createSpy('callback')
          apm.run(['install', 'multi-module'], callback)

          waitsFor 'waiting for install to complete', 600000, ->
            callback.callCount is 1

          runs ->
            expect(fs.existsSync(packageDirectory)).toBeFalsy()
            expect(callback.mostRecentCall.args[0]).not.toBeNull()

    describe 'when multiple package names are specified', ->
      it 'installs all packages', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module", "test-module2", "test-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeNull()

      it "installs them in order and stops on the first failure", ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module", "test-module-bad", "test-module2"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeFalsy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeFalsy()
          expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

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
          expect(callback.mostRecentCall.args[0]).toEqual null

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

    describe "when the package contains symlinks", ->
      it "copies them correctly from the temp directory", ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module-with-symlink')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module-with-symlink"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.isFileSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()

          if process.platform is 'win32'
            expect(fs.isFileSync(path.join(testModuleDirectory, 'node_modules', '.bin', 'abin'))).toBeTruthy()
          else
            expect(fs.realpathSync(path.join(testModuleDirectory, 'node_modules', '.bin', 'abin'))).toBe fs.realpathSync(path.join(testModuleDirectory, 'node_modules', 'test-module-with-bin', 'bin', 'abin.js'))

    describe "when the package installs binaries", ->
      # regression: caused by the existence of `.bin` in the install folder
      it "correctly installs the package ignoring any binaries", ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module-with-bin')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module-with-bin"], callback)

        waitsFor 'waiting for install to complete', 60000, ->
          callback.callCount is 1

        runs ->
          expect(callback.argsForCall[0][0]).toBeFalsy()
          expect(fs.isFileSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()

    describe 'when a packages file is specified', ->
      it 'installs all the packages listed in the file', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')
        packagesFilePath = path.join(__dirname, 'fixtures', 'packages.txt')

        callback = jasmine.createSpy('callback')
        apm.run(['install', '--packages-file', packagesFilePath], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeNull()

      it 'calls back with an error when the file does not exist', ->
        badFilePath = path.join(__dirname, 'fixtures', 'not-packages.txt')

        callback = jasmine.createSpy('callback')
        apm.run(['install', '--packages-file', badFilePath], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).not.toBeNull()

    describe 'when the package is bundled with Atom', ->
      it 'logs a message to standard error', ->
        CSON.writeFileSync(path.join(resourcePath, 'package.json'), packageDependencies: 'test-module': '1.0')

        callback = jasmine.createSpy('callback')
        apm.run(['install', 'test-module'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0

    describe 'when --check is specified', ->
      it 'compiles a sample native module', ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', '--check'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).toBeUndefined()

    describe 'when a deprecated package name is specified', ->
      it 'does not install the package', ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', "atom-2048"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).toBeTruthy()

    describe '::getNormalizedGitUrls', ->
      it 'normalizes https:// urls', ->
        url = "https://github.com/user/repo.git"
        urls = new Install().getNormalizedGitUrls url
        expect(urls).toEqual [url]

      it 'normalizes git@ urls', ->
        url = "git@github.com:user/repo.git"
        urls = new Install().getNormalizedGitUrls url
        expect(urls).toEqual ["git+ssh://git@github.com/user/repo.git"]

      it 'normalizes file:// urls', ->
        url = "file:///path/to/folder"
        urls = new Install().getNormalizedGitUrls url
        expect(urls).toEqual [url]

      it 'normalizes user/repo shortcuts into both HTTPS and SSH URLs', ->
        url = "user/repo"
        urls = new Install().getNormalizedGitUrls url
        expect(urls).toEqual ["https://github.com/user/repo.git", "git+ssh://git@github.com/user/repo.git"]

    describe '::cloneFirstValidGitUrl', ->
      describe 'when cloning a URL fails', ->
        install = null
        urls = ["url1", "url2", "url3", "url4"]

        beforeEach ->
          install = new Install()

          fakeCloneRepository = (url, args...) ->
            callback = args[args.length - 1]
            unless url is urls[2]
              callback(new Error("Failed to clone"))

          spyOn(install, "cloneNormalizedUrl").andCallFake(fakeCloneRepository)

        it 'tries cloning the next URL until one works', ->
          install.cloneFirstValidGitUrl urls, {}, ->
          expect(install.cloneNormalizedUrl.calls.length).toBe 3
          expect(install.cloneNormalizedUrl.argsForCall[0][0]).toBe urls[0]
          expect(install.cloneNormalizedUrl.argsForCall[1][0]).toBe urls[1]
          expect(install.cloneNormalizedUrl.argsForCall[2][0]).toBe urls[2]

    describe 'when installing a package from a git repository', ->
      [cloneUrl, pkgJsonPath] = []

      beforeEach ->
        count = 0
        gitRepo = path.join(__dirname, "fixtures", "test-git-repo.git")
        cloneUrl = "file://#{gitRepo}"

        apm.run ["install", cloneUrl], -> count++

        waitsFor 10000, ->
          count is 1

        runs ->
          pkgJsonPath = path.join(process.env.ATOM_HOME, 'packages', 'test-git-repo', 'package.json')

      it 'installs the repository with a working dir to $ATOM_HOME/packages', ->
        expect(fs.existsSync(pkgJsonPath)).toBeTruthy()

      it 'adds apmInstallSource to the package.json with the source and sha', ->
        sha = '8ae432341ac6708aff9bb619eb015da14e9d0c0f'
        json = require(pkgJsonPath)
        expect(json.apmInstallSource).toEqual
          type: 'git'
          source: cloneUrl
          sha: sha

      it 'installs dependencies and devDependencies', ->
        json = require(pkgJsonPath)
        deps = Object.keys(json.dependencies)
        devDeps = Object.keys(json.devDependencies)
        allDeps = deps.concat(devDeps)
        expect(allDeps).toEqual ["tiny-node-module-one", "tiny-node-module-two"]
        allDeps.forEach (dep) ->
          modPath = path.join(process.env.ATOM_HOME, 'packages', 'test-git-repo', 'node_modules', dep)
          expect(fs.existsSync(modPath)).toBeTruthy()

    describe 'when installing a Git URL and --json is specified', ->
      [cloneUrl, pkgJsonPath] = []

      beforeEach ->
        callback = jasmine.createSpy('callback')
        gitRepo = path.join(__dirname, "fixtures", "test-git-repo.git")
        cloneUrl = "file://#{gitRepo}"

        apm.run ["install", cloneUrl, '--json'], callback

        waitsFor 10000, ->
          callback.callCount is 1

        runs ->
          pkgJsonPath = path.join(process.env.ATOM_HOME, 'packages', 'test-git-repo', 'package.json')

      it 'logs the installation path and the package metadata for a package installed via git url', ->
        sha = '8ae432341ac6708aff9bb619eb015da14e9d0c0f'
        expect(process.stdout.write.calls.length).toBe 0
        json = JSON.parse(console.log.argsForCall[0][0])
        expect(json.length).toBe 1
        expect(json[0].installPath).toBe path.join(process.env.ATOM_HOME, 'packages', 'test-git-repo')
        expect(json[0].metadata.name).toBe 'test-git-repo'
        expect(json[0].metadata.apmInstallSource).toEqual
          type: 'git'
          source: cloneUrl
          sha: sha

    describe 'when installing a registred package and --json is specified', ->
      beforeEach ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module", "test-module2", "--json"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

      it 'logs the installation path and the package metadata for a registered package', ->
        expect(process.stdout.write.calls.length).toBe 0
        json = JSON.parse(console.log.argsForCall[0][0])
        expect(json.length).toBe 2
        expect(json[0].installPath).toBe path.join(process.env.ATOM_HOME, 'packages', 'test-module')
        expect(json[0].metadata.name).toBe 'test-module'
        expect(json[1].installPath).toBe path.join(process.env.ATOM_HOME, 'packages', 'test-module2')
        expect(json[1].metadata.name).toBe 'test-module2'
