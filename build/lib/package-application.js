'use strict'

// This is where we'll run electron-packager on our intermediate app dir.
// It takes an ignore regex for paths to exclude, and I've started on a function
// to build up this regexp based on existing work in build-task.coffee. We should
// try to lean on electron-packager to do as much of the work for us as possible
// other than transpilation. It looks like it has a programmatic API. We'll need to
// copy more stuff such as the package.json for the packager to work correctly.

const path = require('path')
const electronPackager = require('electron-packager')

const CONFIG = require('../config')

module.exports = function () {
  console.log(`Running electron-packager on ${CONFIG.intermediateAppPath}`)
  electronPackager({
    'app-version': CONFIG.appMetadata.version,
    'arch': process.arch,
    'asar': {unpack: buildAsarUnpackGlobExpression()},
    'build-version': CONFIG.appMetadata.version,
    'download': {cache: CONFIG.cachePath},
    'dir': CONFIG.intermediateAppPath,
    'ignore': buildIgnoredPathsRegExp(),
    'out': CONFIG.buildOutputPath,
    'overwrite': true,
    'platform': process.platform,
    'version': CONFIG.appMetadata.electronVersion
  }, (err, appPaths) => {
    if (err) {
      console.error(err)
    } else {
      console.log(`Application bundle(s) created on ${appPaths}`)
    }
  })
}

function buildAsarUnpackGlobExpression () {
  const unpack = [
    '*.node',
    'ctags-config',
    'ctags-darwin',
    'ctags-linux',
    'ctags-win32.exe',
    path.join('**', 'node_modules', 'spellchecker', '**'),
    path.join('**', 'resources', 'atom.png')
  ]

  return `{${unpack.join(',')}}`
}

function buildIgnoredPathsRegExp () {
  const ignoreRegExps = [
    escapeRegExp('.DS_Store'),
    escapeRegExp('.jshintrc'),
    escapeRegExp('.npmignore'),
    escapeRegExp('.pairs'),
    escapeRegExp('.travis.yml'),
    escapeRegExp('appveyor.yml'),
    escapeRegExp('.idea'),
    escapeRegExp('.editorconfig'),
    escapeRegExp('.lint'),
    escapeRegExp('.lintignore'),
    escapeRegExp('.eslintrc'),
    escapeRegExp('.jshintignore'),
    escapeRegExp('coffeelint.json'),
    escapeRegExp('.coffeelintignore'),
    escapeRegExp('.gitattributes'),
    escapeRegExp('.gitkeep'),
    escapeRegExp(path.join('git-utils', 'deps')),
    escapeRegExp(path.join('oniguruma', 'deps')),
    escapeRegExp(path.join('less', 'dist')),
    escapeRegExp(path.join('pegjs', 'examples')),
    escapeRegExp(path.join('get-parameter-names', 'node_modules', 'testla')),
    escapeRegExp(path.join('get-parameter-names', 'node_modules', '.bin', 'testla')),
    escapeRegExp(path.join('jasmine-reporters', 'ext')),
    escapeRegExp(path.join('node_modules', 'nan')),
    escapeRegExp(path.join('node_modules', 'native-mate')),
    escapeRegExp(path.join('build', 'binding.Makefile')),
    escapeRegExp(path.join('build', 'config.gypi')),
    escapeRegExp(path.join('build', 'gyp-mac-tool')),
    escapeRegExp(path.join('build', 'Makefile')),
    escapeRegExp(path.join('build', 'Release', 'obj.target')),
    escapeRegExp(path.join('build', 'Release', 'obj')),
    escapeRegExp(path.join('build', 'Release', '.deps')),
    escapeRegExp(path.join('vendor', 'apm')),

    // These are only required in dev-mode, when pegjs grammars aren't precompiled
    escapeRegExp(path.join('node_modules', 'loophole')),
    escapeRegExp(path.join('node_modules', 'pegjs')),
    escapeRegExp(path.join('node_modules', '.bin', 'pegjs')),
    escapeRegExp(path.join('node_modules', 'spellchecker', 'vendor', 'hunspell') + path.sep) + '.*',
    escapeRegExp(path.join('build', 'Release') + path.sep) + '.*\\.pdb',

    // Ignore *.cc and *.h files from native modules
    escapeRegExp(path.join('ctags', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('git-utils', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('keytar', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('nslog', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('oniguruma', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('pathwatcher', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('runas', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('scrollbar-style', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('spellchecker', 'src') + path.sep) + '.*\\.(cc|h)*',
    escapeRegExp(path.join('cached-run-in-this-context', 'src') + path.sep) + '.*\\.(cc|h)?',
    escapeRegExp(path.join('keyboard-layout', 'src') + path.sep) + '.*\\.(cc|h|mm)*',

    // Ignore build files
    escapeRegExp(path.sep) + 'binding\\.gyp$',
    escapeRegExp(path.sep) + '.+\\.target.mk$',
    escapeRegExp(path.sep) + 'linker\\.lock$',
    escapeRegExp(path.join('build', 'Release') + path.sep) + '.+\\.node\\.dSYM',

    // Ignore test, spec and example folders for packages
    'node_modules' + escapeRegExp(path.sep) + '.*' + escapeRegExp(path.sep) + '_*te?sts?_*' + escapeRegExp(path.sep),
    'node_modules' + escapeRegExp(path.sep) + '.*' + escapeRegExp(path.sep) + 'spec' + escapeRegExp(path.sep),
    'node_modules' + escapeRegExp(path.sep) + '.*' + escapeRegExp(path.sep) + 'examples?' + escapeRegExp(path.sep),
  ]
  // Ignore Hunspell dictionaries only on macOS.
  if (process.platform === 'darwin') {
    ignoreRegExps.push(escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell_dictionaries')))
  }

  const regExpSource = ignoreRegExps.map(path => `(${path})`).join('|')
  return new RegExp(regExpSource)
}

function escapeRegExp (string) {
  return string.replace(/[.?*+^$[\]\\(){}|-]/g, "\\$&")
}
