/** @babel */
import path from 'path';

import PackageTranspilationRegistry from '../src/package-transpilation-registry';

const originalCompiler = {
  getCachePath: (sourceCode, filePath) => {
    return 'orig-cache-path';
  },

  compile: (sourceCode, filePath) => {
    return sourceCode + '-original-compiler';
  },

  shouldCompile: (sourceCode, filePath) => {
    return path.extname(filePath) === '.js';
  }
};

describe('PackageTranspilationRegistry', () => {
  let registry;
  let wrappedCompiler;

  beforeEach(() => {
    registry = new PackageTranspilationRegistry();
    wrappedCompiler = registry.wrapTranspiler(originalCompiler);
  });

  it('falls through to the original compiler by default', () => {
    spyOn(originalCompiler, 'getCachePath');
    spyOn(originalCompiler, 'compile');
    spyOn(originalCompiler, 'shouldCompile');

    wrappedCompiler.getCachePath('source', '/path/to/file.js');
    wrappedCompiler.compile('source', '/path/to/filejs');
    wrappedCompiler.shouldCompile('source', '/path/to/file.js');

    expect(originalCompiler.getCachePath).toHaveBeenCalled();
    expect(originalCompiler.compile).toHaveBeenCalled();
    expect(originalCompiler.shouldCompile).toHaveBeenCalled();
  });

  describe('when a file is contained in a path that has custom transpilation', () => {
    const hitPath = path.join('/path/to/lib/file.js');
    const hitPathCoffee = path.join('/path/to/file2.coffee');
    const missPath = path.join('/path/other/file3.js');
    const hitPathMissSubdir = path.join('/path/to/file4.js');
    const hitPathMissExt = path.join('/path/to/file5.ts');
    const nodeModulesFolder = path.join('/path/to/lib/node_modules/file6.js');
    const hitNonStandardExt = path.join('/path/to/file7.omgwhatisthis');

    const jsSpec = {
      glob: 'lib/**/*.js',
      transpiler: './transpiler-js',
      options: { type: 'js' }
    };
    const coffeeSpec = {
      glob: '*.coffee',
      transpiler: './transpiler-coffee',
      options: { type: 'coffee' }
    };
    const omgSpec = {
      glob: '*.omgwhatisthis',
      transpiler: './transpiler-omg',
      options: { type: 'omg' }
    };

    const expectedMeta = {
      name: 'my-package',
      path: path.join('/path/to'),
      meta: { some: 'metadata' }
    };

    const jsTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return { code: sourceCode + '-transpiler-js' };
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'js-transpiler-cache-data';
      }
    };

    const coffeeTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return { code: sourceCode + '-transpiler-coffee' };
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'coffee-transpiler-cache-data';
      }
    };

    const omgTranspiler = {
      transpile: (sourceCode, filePath, options) => {
        return { code: sourceCode + '-transpiler-omg' };
      },

      getCacheKeyData: (sourceCode, filePath, options) => {
        return 'omg-transpiler-cache-data';
      }
    };

    beforeEach(() => {
      jsSpec._transpilerSource = 'js-transpiler-source';
      coffeeSpec._transpilerSource = 'coffee-transpiler-source';
      omgTranspiler._transpilerSource = 'omg-transpiler-source';

      spyOn(registry, 'getTranspiler').andCallFake(spec => {
        if (spec.transpiler === './transpiler-js') return jsTranspiler;
        if (spec.transpiler === './transpiler-coffee') return coffeeTranspiler;
        if (spec.transpiler === './transpiler-omg') return omgTranspiler;
        throw new Error('bad transpiler path ' + spec.transpiler);
      });

      registry.addTranspilerConfigForPath(
        path.join('/path/to'),
        'my-package',
        { some: 'metadata' },
        [jsSpec, coffeeSpec, omgSpec]
      );
    });

    it('always returns true from shouldCompile for a file in that dir that match a glob', () => {
      spyOn(originalCompiler, 'shouldCompile').andReturn(false);
      expect(wrappedCompiler.shouldCompile('source', hitPath)).toBe(true);
      expect(wrappedCompiler.shouldCompile('source', hitPathCoffee)).toBe(true);
      expect(wrappedCompiler.shouldCompile('source', hitNonStandardExt)).toBe(
        true
      );
      expect(wrappedCompiler.shouldCompile('source', hitPathMissExt)).toBe(
        false
      );
      expect(wrappedCompiler.shouldCompile('source', hitPathMissSubdir)).toBe(
        false
      );
      expect(wrappedCompiler.shouldCompile('source', missPath)).toBe(false);
      expect(wrappedCompiler.shouldCompile('source', nodeModulesFolder)).toBe(
        false
      );
    });

    it('calls getCacheKeyData on the transpiler to get additional cache key data', () => {
      spyOn(registry, 'getTranspilerPath').andReturn('./transpiler-js');
      spyOn(jsTranspiler, 'getCacheKeyData').andCallThrough();

      wrappedCompiler.getCachePath('source', missPath, jsSpec);
      expect(jsTranspiler.getCacheKeyData).not.toHaveBeenCalledWith(
        'source',
        missPath,
        jsSpec.options,
        expectedMeta
      );
      wrappedCompiler.getCachePath('source', hitPath, jsSpec);
      expect(jsTranspiler.getCacheKeyData).toHaveBeenCalledWith(
        'source',
        hitPath,
        jsSpec.options,
        expectedMeta
      );
    });

    it('compiles files matching a glob with the associated transpiler, and the old one otherwise', () => {
      spyOn(jsTranspiler, 'transpile').andCallThrough();
      spyOn(coffeeTranspiler, 'transpile').andCallThrough();
      spyOn(omgTranspiler, 'transpile').andCallThrough();

      expect(wrappedCompiler.compile('source', hitPath)).toEqual(
        'source-transpiler-js'
      );
      expect(jsTranspiler.transpile).toHaveBeenCalledWith(
        'source',
        hitPath,
        jsSpec.options,
        expectedMeta
      );
      expect(wrappedCompiler.compile('source', hitPathCoffee)).toEqual(
        'source-transpiler-coffee'
      );
      expect(coffeeTranspiler.transpile).toHaveBeenCalledWith(
        'source',
        hitPathCoffee,
        coffeeSpec.options,
        expectedMeta
      );
      expect(wrappedCompiler.compile('source', hitNonStandardExt)).toEqual(
        'source-transpiler-omg'
      );
      expect(omgTranspiler.transpile).toHaveBeenCalledWith(
        'source',
        hitNonStandardExt,
        omgSpec.options,
        expectedMeta
      );

      expect(wrappedCompiler.compile('source', missPath)).toEqual(
        'source-original-compiler'
      );
      expect(wrappedCompiler.compile('source', hitPathMissExt)).toEqual(
        'source-original-compiler'
      );
      expect(wrappedCompiler.compile('source', hitPathMissSubdir)).toEqual(
        'source-original-compiler'
      );
      expect(wrappedCompiler.compile('source', nodeModulesFolder)).toEqual(
        'source-original-compiler'
      );
    });

    describe('when the packages root path contains node_modules', () => {
      beforeEach(() => {
        registry.addTranspilerConfigForPath(
          path.join('/path/with/node_modules/in/root'),
          'my-other-package',
          { some: 'metadata' },
          [jsSpec]
        );
      });

      it('returns appropriate values from shouldCompile', () => {
        spyOn(originalCompiler, 'shouldCompile').andReturn(false);
        expect(
          wrappedCompiler.shouldCompile(
            'source',
            '/path/with/node_modules/in/root/lib/test.js'
          )
        ).toBe(true);
        expect(
          wrappedCompiler.shouldCompile(
            'source',
            '/path/with/node_modules/in/root/lib/node_modules/test.js'
          )
        ).toBe(false);
      });
    });
  });
});
