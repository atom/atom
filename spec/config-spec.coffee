path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe "apm config", ->
  [atomHome, userConfigPath] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    userConfigPath = path.join(atomHome, '.apmrc')

    # Make sure the cache used is the one for the test env
    delete process.env.npm_config_cache

  describe "apm config get", ->
    it "reads the value from the global config when there is no user config", ->
      callback = jasmine.createSpy('callback')
      apm.run(['config', 'get', 'cache'], callback)

      waitsFor 'waiting for config get to complete', 600000, ->
        callback.callCount is 1

      runs ->
        expect(process.stdout.write.argsForCall[0][0].trim()).toBe path.join(process.env.ATOM_HOME, '.apm')

  describe "apm config set", ->
    it "sets the value in the user config", ->
      expect(fs.isFileSync(userConfigPath)).toBe false

      callback = jasmine.createSpy('callback')
      apm.run(['config', 'set', 'foo', 'bar'], callback)

      waitsFor 'waiting for config set to complete', 600000, ->
        callback.callCount is 1

      runs ->
        expect(fs.isFileSync(userConfigPath)).toBe true

        callback.reset()
        apm.run(['config', 'get', 'foo'], callback)

      waitsFor 'waiting for config get to complete', 600000, ->
        callback.callCount is 1

      runs ->
        expect(process.stdout.write.argsForCall[0][0].trim()).toBe 'bar'
