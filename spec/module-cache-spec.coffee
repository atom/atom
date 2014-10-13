path = require 'path'
Module = require 'module'

describe 'ModuleCache', ->
  beforeEach ->
    spyOn(Module, '_findPath').andCallThrough()

  it 'resolves atom shell module paths without hitting the filesystem', ->
    require.resolve('shell')
    expect(Module._findPath.callCount).toBe 0
