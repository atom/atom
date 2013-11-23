path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe 'apm uninstall', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

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
      fs.makeTreeSync(path.join(packagePath, 'lib'))
      fs.writeFileSync(path.join(packagePath, 'package.json'), "{}")
      process.env.ATOM_HOME = atomHome

      expect(fs.existsSync(packagePath)).toBeTruthy()
      callback = jasmine.createSpy('callback')
      apm.run(['uninstall', 'test-package'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(packagePath)).toBeFalsy()
