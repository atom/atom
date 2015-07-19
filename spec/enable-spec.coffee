fs = require 'fs'
path = require 'path'
temp = require 'temp'
CSON = require 'season'

apm = require '../lib/apm-cli'

describe 'apm enable', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

  fit 'enables a disabled package', ->
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
          "ex-mode"
        ]

    runs ->
      apm.run(['enable', 'vim-mode', 'ex-mode'], callback)

    waitsFor 'waiting for enable to complete', ->
      callback.callCount > 0

    runs ->
      config = CSON.readFileSync(configFilePath)
      expect(config).toEqual '*':
        core:
          disabledPackages: [
            "metrics"
            "exception-reporting"
          ]

  it 'does nothing if a package is already enabled', ->

  it 'produces an error if config.cson doesn\'t exist', ->

  it 'complains if user supplies no packages', ->
