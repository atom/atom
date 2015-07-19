fs = require 'fs'
path = require 'path'
temp = require 'temp'
CSON = require 'season'

apm = require '../lib/apm-cli'

describe 'apm disable', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

  it 'disables an enabled package', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')
    configFilePath = path.join(atomHome, 'config.cson')

    CSON.writeFileSync configFilePath, '*':
      core:
        disabledPackages: [
          "vim-mode"
          "file-icons"
        ]

    runs ->
      apm.run(['disable', 'metrics', 'exception-reporting'], callback)

    waitsFor 'waiting for disable to complete', ->
      callback.callCount > 0

    runs ->
      config = CSON.readFileSync(configFilePath)
      expect(config).toEqual '*':
        core:
          disabledPackages: [
            "vim-mode"
            "file-icons"
            "metrics"
            "exception-reporting"
          ]

  it 'does nothing if a package is already disabled', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')
    configFilePath = path.join(atomHome, 'config.cson')

    CSON.writeFileSync configFilePath, '*':
      core:
        disabledPackages: [
          "vim-mode"
          "file-icons"
          "metrics"
          "exception-reporting"
        ]

    runs ->
      apm.run(['disable', 'vim-mode', 'metrics'], callback)

    waitsFor 'waiting for disable to complete', ->
      callback.callCount > 0

    runs ->
      config = CSON.readFileSync(configFilePath)
      expect(config).toEqual '*':
        core:
          disabledPackages: [
            "vim-mode"
            "file-icons"
            "metrics"
            "exception-reporting"
          ]

  it 'produces an error if config.cson doesn\'t exist', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')

    runs ->
      apm.run(['disable', 'vim-mode'], callback)

    waitsFor 'waiting for disable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  it 'complains if user supplies no packages', ->
    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    callback = jasmine.createSpy('callback')

    runs ->
      apm.run(['disable'], callback)

    waitsFor 'waiting for disable to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0
