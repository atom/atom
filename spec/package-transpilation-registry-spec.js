/** @babel */
import fs from 'fs'
import path from 'path'

import {it, fit, ffit, fffit, beforeEach, afterEach} from './async-spec-helpers'

import PackageTranspilationRegistry from '../src/package-transpilation-registry'

let originalCompiler = {
  getCachePath: (sourceCode, filePath) => {
    return "orig-cache-path"
  },

  compile: (sourceCode, filePath) => {
    return sourceCode + "-original-compiler"
  },

  shouldCompile: (sourceCode, filePath) => {
    return path.extname(filePath) === '.js'
  }
}

describe("PackageTranspilationRegistry", () => {
  let registry
  let wrappedCompiler

  beforeEach(() => {
    registry = new PackageTranspilationRegistry()
    wrappedCompiler = registry.wrapTranspiler(originalCompiler)
  })

  it('falls through to the original compiler by default', () => {
    spyOn(originalCompiler, 'getCachePath')
    spyOn(originalCompiler, 'compile')
    spyOn(originalCompiler, 'shouldCompile')

    wrappedCompiler.getCachePath('source', '/path/to/file.js')
    wrappedCompiler.compile('source', '/path/to/filejs')
    wrappedCompiler.shouldCompile('source', '/path/to/file.js')

    expect(originalCompiler.getCachePath).toHaveBeenCalled()
    expect(originalCompiler.compile).toHaveBeenCalled()
    expect(originalCompiler.shouldCompile).toHaveBeenCalled()
  })

  describe('when a file is contained in a path that has custom transpilation', () => {
    let hitPath = '/path/to/lib/file.js'
    let hitPathCoffee = '/path/to/file2.coffee'
    let missPath = '/path/other/file3.js'
    let hitPathMissSubdir = '/path/to/file4.js'
    let hitPathMissExt = '/path/to/file5.ts'
    let nodeModulesFolder = '/path/to/lib/node_modules/file6.js'
    let hitNonStandardExt = '/path/to/file7.omgwhatisthis'

    let jsSpec = { glob: "lib/**/*.js", transpiler: './transpiler-js', options: { type: 'js' } }
    let coffeeSpec = { glob: "*.coffee", transpiler: './transpiler-coffee', options: { type: 'coffee' } }
    let omgSpec = { glob: "*.omgwhatisthis", transpiler: './transpiler-omg', options: { type: 'omg' } }

    let jsTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return {code: sourceCode + "-transpiler-js"}
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'js-transpiler-cache-data'
      }
    }

    let coffeeTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return {code: sourceCode + "-transpiler-coffee"}
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'coffee-transpiler-cache-data'
      }
    }

    let omgTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return {code: sourceCode + "-transpiler-omg"}
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'omg-transpiler-cache-data'
      }
    }

    beforeEach(() => {
      jsSpec._transpilerSource = "js-transpiler-source"
      coffeeSpec._transpilerSource = "coffee-transpiler-source"
      omgTranspiler._transpilerSource = "omg-transpiler-source"

      spyOn(registry, "getTranspiler").andCallFake(spec => {
        if (spec.transpiler === './transpiler-js') return jsTranspiler
        if (spec.transpiler === './transpiler-coffee') return coffeeTranspiler
        if (spec.transpiler === './transpiler-omg') return omgTranspiler
        throw new Error('bad transpiler path ' + spec.transpiler)
      })

      registry.addTranspilerConfigForPath('/path/to', 'my-package', [
        jsSpec, coffeeSpec, omgSpec
      ])
    })

    it('always returns true from shouldCompile for a file in that dir that match a glob', () => {
      spyOn(originalCompiler, 'shouldCompile').andReturn(false)
      expect(wrappedCompiler.shouldCompile('source', hitPath)).toBe(true)
      expect(wrappedCompiler.shouldCompile('source', hitPathCoffee)).toBe(true)
      expect(wrappedCompiler.shouldCompile('source', hitNonStandardExt)).toBe(true)
      expect(wrappedCompiler.shouldCompile('source', hitPathMissExt)).toBe(false)
      expect(wrappedCompiler.shouldCompile('source', hitPathMissSubdir)).toBe(false)
      expect(wrappedCompiler.shouldCompile('source', missPath)).toBe(false)
      expect(wrappedCompiler.shouldCompile('source', nodeModulesFolder)).toBe(false)
    })

    it('calls getCacheKeyData on the transpiler to get additional cache key data', () => {
      spyOn(registry, "getTranspilerPath").andReturn("./transpiler-js")
      spyOn(jsTranspiler, 'getCacheKeyData').andCallThrough()

      wrappedCompiler.getCachePath('source', missPath, jsSpec)
      expect(jsTranspiler.getCacheKeyData).not.toHaveBeenCalled()
      wrappedCompiler.getCachePath('source', hitPath, jsSpec)
      expect(jsTranspiler.getCacheKeyData).toHaveBeenCalled()
    })

    it('compiles files matching a glob with the associated transpiler, and the old one otherwise', () => {
      spyOn(jsTranspiler, "transpile").andCallThrough()
      spyOn(coffeeTranspiler, "transpile").andCallThrough()
      spyOn(omgTranspiler, "transpile").andCallThrough()

      expect(wrappedCompiler.compile('source', hitPath)).toEqual('source-transpiler-js')
      expect(jsTranspiler.transpile).toHaveBeenCalledWith('source', hitPath, jsSpec.options)
      expect(wrappedCompiler.compile('source', hitPathCoffee)).toEqual('source-transpiler-coffee')
      expect(coffeeTranspiler.transpile).toHaveBeenCalledWith('source', hitPathCoffee, coffeeSpec.options)
      expect(wrappedCompiler.compile('source', hitNonStandardExt)).toEqual('source-transpiler-omg')
      expect(omgTranspiler.transpile).toHaveBeenCalledWith('source', hitNonStandardExt, omgSpec.options)

      expect(wrappedCompiler.compile('source', missPath)).toEqual('source-original-compiler')
      expect(wrappedCompiler.compile('source', hitPathMissExt)).toEqual('source-original-compiler')
      expect(wrappedCompiler.compile('source', hitPathMissSubdir)).toEqual('source-original-compiler')
      expect(wrappedCompiler.compile('source', nodeModulesFolder)).toEqual('source-original-compiler')
    })
  })
})
