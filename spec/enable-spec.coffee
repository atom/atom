fs = require 'fs'
path = require 'path'
temp = require 'temp'
CSON = require 'season'

apm = require '../lib/apm-cli'

describe 'apm enable', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

  it 'enables a disabled package', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')
    configFilePath = path.join(atomHome, 'config.cson')

    CSON.writeFileSync configFilePath, '*':
      core:
        disabledPackages: [
          "metrics"
          "vim-mode"
          "exception-reporting"
          "file-icons"
        ]

    runs ->
      apm.run(['enable', 'vim-mode', 'not-installed', 'file-icons'], callback)

    waitsFor 'waiting for enable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[0][0]).toMatch /Not Disabled:\s*not-installed/
      expect(console.log.argsForCall[1][0]).toMatch /Enabled:\s*vim-mode/

      config = CSON.readFileSync(configFilePath)
      expect(config).toEqual '*':
        core:
          disabledPackages: [
            "metrics"
            "exception-reporting"
          ]

  it 'does nothing if a package is already enabled', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')
    configFilePath = path.join(atomHome, 'config.cson')

    CSON.writeFileSync configFilePath, '*':
      core:
        disabledPackages: [
          "metrics"
          "exception-reporting"
        ]

    runs ->
      apm.run(['enable', 'vim-mode'], callback)

    waitsFor 'waiting for enable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[0][0]).toMatch /Not Disabled:\s*vim-mode/

      config = CSON.readFileSync(configFilePath)
      expect(config).toEqual '*':
        core:
          disabledPackages: [
            "metrics"
            "exception-reporting"
          ]

  it 'produces an error if config.cson doesn\'t exist', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')

    runs ->
      apm.run(['enable', 'vim-mode'], callback)

    waitsFor 'waiting for enable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  it 'complains if user supplies no packages', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')

    runs ->
      apm.run(['enable'], callback)

    waitsFor 'waiting for enable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0
