path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

listPackages = (args, doneCallback) ->
  callback = jasmine.createSpy('callback')
  apm.run ['list'].concat(args), callback

  waitsFor -> callback.callCount is 1

  runs(doneCallback)

createFakePackage = (type, metadata) ->
  packagesFolder = switch type
    when "user", "git" then "packages"
    when "dev" then path.join("dev", "packages")
  targetFolder = path.join(process.env.ATOM_HOME, packagesFolder, metadata.name)
  fs.makeTreeSync targetFolder
  fs.writeFileSync path.join(targetFolder, 'package.json'), JSON.stringify(metadata)

describe 'apm list', ->
  [resourcePath, atomHome] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    resourcePath = temp.mkdirSync('apm-resource-path-')
    atomPackages =
      'test-module':
        metadata:
          name: 'test-module'
          version: '1.0.0'
    fs.writeFileSync(path.join(resourcePath, 'package.json'), JSON.stringify(_atomPackages: atomPackages))
    process.env.ATOM_RESOURCE_PATH = resourcePath
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome

    createFakePackage "user",
      name: "user-package"
      version: "1.0.0"
    createFakePackage "dev",
      name: "dev-package"
      version: "1.0.0"
    createFakePackage "git",
      name: "git-package"
      version: "1.0.0"
      apmInstallSource:
        type: "git"
        source: "git+ssh://git@github.com:user/repo.git"
        sha: "abcdef1234567890"

    badPackagePath = path.join(process.env.ATOM_HOME, "packages", ".bin")
    fs.makeTreeSync badPackagePath
    fs.writeFileSync path.join(badPackagePath, "file.txt"), "some fake stuff"

  it 'lists the packages included the _atomPackages section of the package.json', ->
    listPackages [], ->
      expect(console.log.argsForCall[1][0]).toContain 'test-module@1.0.0'

  it 'lists the installed packages', ->
    listPackages [], ->
      lines = console.log.argsForCall.map((arr) -> arr.join(' '))
      expect(lines[0]).toMatch /Built-in Atom Packages.*1/
      expect(lines[1]).toMatch /test-module@1\.0\.0/
      expect(lines[3]).toMatch /Dev Packages.*1/
      expect(lines[4]).toMatch /dev-package@1\.0\.0/
      expect(lines[6]).toMatch /Community Packages.*1/
      expect(lines[7]).toMatch /user-package@1\.0\.0/
      expect(lines[9]).toMatch /Git Packages.*1/
      expect(lines[10]).toMatch /git-package@1\.0\.0/
      expect(lines.join("\n")).not.toContain '.bin' # ensure invalid packages aren't listed

  it 'labels disabled packages', ->
    packagesPath = path.join(atomHome, 'packages')
    fs.makeTreeSync(packagesPath)
    wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module'), path.join(packagesPath, 'test-module'))
    configPath = path.join(atomHome, 'config.cson')
    fs.writeFileSync(configPath, 'core: disabledPackages: ["test-module"]')

    listPackages [], ->
      expect(console.log.argsForCall[1][0]).toContain 'test-module@1.0.0 (disabled)'

  it 'lists packages in json format when --json is passed', ->
    listPackages ['--json'], ->
      json = JSON.parse(console.log.argsForCall[0][0])
      apmInstallSource =
        type: 'git'
        source: 'git+ssh://git@github.com:user/repo.git'
        sha: 'abcdef1234567890'
      expect(json.core).toEqual [name: 'test-module', version: '1.0.0']
      expect(json.dev).toEqual [name: 'dev-package', version: '1.0.0']
      expect(json.git).toEqual [name: 'git-package', version: '1.0.0', apmInstallSource: apmInstallSource]
      expect(json.user).toEqual [name: 'user-package', version: '1.0.0']
