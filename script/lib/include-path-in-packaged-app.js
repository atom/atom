'use strict'

const path = require('path')
const CONFIG = require('../config')

module.exports = function (path) {
  return !EXCLUDED_PATHS_REGEXP.test(path)
}

const EXCLUDE_REGEXPS_SOURCES = [
  escapeRegExp('.DS_Store'),
  escapeRegExp('.jshintrc'),
  escapeRegExp('.npmignore'),
  escapeRegExp('.pairs'),
  escapeRegExp('.travis.yml'),
  escapeRegExp('appveyor.yml'),
  escapeRegExp('circle.yml'),
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
  escapeRegExp(path.join('npm', 'doc')),
  escapeRegExp(path.join('npm', 'html')),
  escapeRegExp(path.join('npm', 'man')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'beep')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'clear')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'starwars')),
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

  // Ignore test and example folders
  'node_modules' + escapeRegExp(path.sep) + '.*' + escapeRegExp(path.sep) + '_*te?sts?_*' + escapeRegExp(path.sep),
  'node_modules' + escapeRegExp(path.sep) + '.*' + escapeRegExp(path.sep) + 'examples?' + escapeRegExp(path.sep),
]

// Ignore spec directories in all bundled packages
for (let packageName in CONFIG.appMetadata.packageDependencies) {
  EXCLUDE_REGEXPS_SOURCES.push('^' + escapeRegExp(path.join(CONFIG.repositoryRootPath, 'node_modules', packageName, 'spec')))
}

// Ignore Hunspell dictionaries only on macOS.
if (process.platform === 'darwin') {
  EXCLUDE_REGEXPS_SOURCES.push(escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell_dictionaries')))
}

const EXCLUDED_PATHS_REGEXP = new RegExp(
  EXCLUDE_REGEXPS_SOURCES.map(path => `(${path})`).join('|')
)

function escapeRegExp (string) {
  return string.replace(/[.?*+^$[\]\\(){}|-]/g, "\\$&")
}
