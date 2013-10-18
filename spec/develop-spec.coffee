fs = require 'fs'
path = require 'path'
temp = require 'temp'
apm = require '../lib/apm-cli'
mkdir = require('mkdirp').sync

describe "apm develop", ->
  [repoPath, linkedRepoPath] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

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
