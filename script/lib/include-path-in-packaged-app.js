'use strict';

const path = require('path');
const CONFIG = require('../config');

module.exports = function(filePath) {
  return (
    !EXCLUDED_PATHS_REGEXP.test(filePath) ||
    INCLUDED_PATHS_REGEXP.test(filePath)
  );
};

const EXCLUDE_REGEXPS_SOURCES = [
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
  escapeRegExp(path.join('npm', 'doc')),
  escapeRegExp(path.join('npm', 'html')),
  escapeRegExp(path.join('npm', 'man')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'beep')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'clear')),
  escapeRegExp(path.join('npm', 'node_modules', '.bin', 'starwars')),
  escapeRegExp(path.join('pegjs', 'examples')),
  escapeRegExp(path.join('get-parameter-names', 'node_modules', 'testla')),
  escapeRegExp(
    path.join('get-parameter-names', 'node_modules', '.bin', 'testla')
  ),
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
  escapeRegExp(path.join('deps', 'libgit2')),
  escapeRegExp(path.join('vendor', 'apm')),

  // These are only required in dev-mode, when pegjs grammars aren't precompiled
  escapeRegExp(path.join('node_modules', 'loophole')),
  escapeRegExp(path.join('node_modules', 'pegjs')),
  escapeRegExp(path.join('node_modules', '.bin', 'pegjs')),
  escapeRegExp(
    path.join('node_modules', 'spellchecker', 'vendor', 'hunspell') + path.sep
  ) + '.*',

  // node_modules of the fuzzy-native package are only required for building it.
  escapeRegExp(path.join('node_modules', 'fuzzy-native', 'node_modules')),

  // Ignore *.cc and *.h files from native modules
  escapeRegExp(path.sep) + '.+\\.(cc|h)$',

  // Ignore build files
  escapeRegExp(path.sep) + 'binding\\.gyp$',
  escapeRegExp(path.sep) + '.+\\.target.mk$',
  escapeRegExp(path.sep) + 'linker\\.lock$',
  escapeRegExp(path.join('build', 'Release') + path.sep) + '.+\\.node\\.dSYM',
  escapeRegExp(path.join('build', 'Release') + path.sep) +
    '.*\\.(pdb|lib|exp|map|ipdb|iobj)',

  // Ignore node_module files we won't need at runtime
  'node_modules' +
    escapeRegExp(path.sep) +
    '.*' +
    escapeRegExp(path.sep) +
    '_*te?sts?_*' +
    escapeRegExp(path.sep),
  'node_modules' +
    escapeRegExp(path.sep) +
    '.*' +
    escapeRegExp(path.sep) +
    'examples?' +
    escapeRegExp(path.sep),
  'node_modules' + escapeRegExp(path.sep) + '.*' + '\\.d\\.ts$',
  'node_modules' + escapeRegExp(path.sep) + '.*' + '\\.js\\.map$',
  '.*' + escapeRegExp(path.sep) + 'test.*\\.html$'
];

// Ignore spec directories in all bundled packages
for (let packageName in CONFIG.appMetadata.packageDependencies) {
  EXCLUDE_REGEXPS_SOURCES.push(
    '^' +
      escapeRegExp(
        path.join(
          CONFIG.repositoryRootPath,
          'node_modules',
          packageName,
          'spec'
        )
      )
  );
}

// Ignore Hunspell dictionaries only on macOS.
if (process.platform === 'darwin') {
  EXCLUDE_REGEXPS_SOURCES.push(
    escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell_dictionaries'))
  );
}

const EXCLUDED_PATHS_REGEXP = new RegExp(
  EXCLUDE_REGEXPS_SOURCES.map(path => `(${path})`).join('|')
);

const INCLUDED_PATHS_REGEXP = new RegExp(
  escapeRegExp(
    path.join('node_modules', 'node-gyp', 'src', 'win_delay_load_hook.cc')
  )
);

function escapeRegExp(string) {
  return string.replace(/[.?*+^$[\]\\(){}|-]/g, '\\$&');
}
