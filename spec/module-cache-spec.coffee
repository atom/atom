path = require 'path'
Module = require 'module'
ModuleCache = require '../src/module-cache'

describe 'ModuleCache', ->
  beforeEach ->
    spyOn(Module, '_findPath').andCallThrough()

  it 'resolves atom shell module paths without hitting the filesystem', ->
    require.resolve('shell')
    expect(Module._findPath.callCount).toBe 0

  it 'resolves relative core paths without hitting the filesystem', ->
    ModuleCache.add atom.getLoadSettings().resourcePath, {
      _atomModuleCache:
        extensions:
          '.json': [
            path.join('spec', 'fixtures', 'module-cache', 'file.json')
          ]
    }
    expect(require('./fixtures/module-cache/file.json').foo).toBe 'bar'
    expect(Module._findPath.callCount).toBe 0
