path = require 'path'
Module = require 'module'
fs = require 'fs-plus'
temp = require 'temp'
ModuleCache = require '../src/module-cache'

describe 'ModuleCache', ->
  beforeEach ->
    spyOn(Module, '_findPath').andCallThrough()

  it 'resolves atom shell module paths without hitting the filesystem', ->
    builtins = ModuleCache.cache.builtins
    expect(Object.keys(builtins).length).toBeGreaterThan 0

    for builtinName, builtinPath of builtins
      expect(require.resolve(builtinName)).toBe builtinPath
      expect(fs.isFileSync(require.resolve(builtinName)))

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

  it 'resolves module paths when a compatible version is provided by core', ->
    packagePath = fs.realpathSync(temp.mkdirSync('atom-package'))
    ModuleCache.add packagePath, {
      _atomModuleCache:
        folders: [{
          paths: [
            ''
          ]
          dependencies:
            'underscore-plus': '*'
        }]
    }
    ModuleCache.add atom.getLoadSettings().resourcePath, {
      _atomModuleCache:
        dependencies: [{
          name: 'underscore-plus'
          version: require('underscore-plus/package.json').version
          path: path.join('node_modules', 'underscore-plus', 'lib', 'underscore-plus.js')
        }]
    }

    indexPath = path.join(packagePath, 'index.js')
    fs.writeFileSync indexPath, """
      exports.load = function() { require('underscore-plus'); };
    """

    packageMain = require(indexPath)
    Module._findPath.reset()
    packageMain.load()
    expect(Module._findPath.callCount).toBe 0

  it 'does not resolve module paths when no compatible version is provided by core', ->
    packagePath = fs.realpathSync(temp.mkdirSync('atom-package'))
    ModuleCache.add packagePath, {
      _atomModuleCache:
        folders: [{
          paths: [
            ''
          ]
          dependencies:
            'underscore-plus': '0.0.1'
        }]
    }
    ModuleCache.add atom.getLoadSettings().resourcePath, {
      _atomModuleCache:
        dependencies: [{
          name: 'underscore-plus'
          version: require('underscore-plus/package.json').version
          path: path.join('node_modules', 'underscore-plus', 'lib', 'underscore-plus.js')
        }]
    }

    indexPath = path.join(packagePath, 'index.js')
    fs.writeFileSync indexPath, """
      exports.load = function() { require('underscore-plus'); };
    """

    packageMain = require(indexPath)
    Module._findPath.reset()
    expect(-> packageMain.load()).toThrow()
    expect(Module._findPath.callCount).toBe 1
