fs = require 'fs'
path = require 'path'
temp = require 'temp'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
mkdir = require('mkdirp').sync

describe 'apm list', ->
  [resourcePath, atomHome] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

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
