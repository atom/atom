// This module exports a function that copies all the static assets into the
// appropriate location in the build output directory.

'use strict'

const path = require('path')
const fs = require('fs-extra')
const CONFIG = require('../config')
const glob = require('glob')

module.exports = function () {
  console.log(`Copying assets to ${CONFIG.intermediateAppPath}...`);
  const ignoredPathsRegExp = buildIgnoredPathsRegExp()
  const skipIgnoredPaths = (path) => !ignoredPathsRegExp.test(path)
  let srcPaths = [
    path.join(CONFIG.repositoryRootPath, 'dot-atom'),
    path.join(CONFIG.repositoryRootPath, 'exports'),
    path.join(CONFIG.repositoryRootPath, 'keymaps'),
    path.join(CONFIG.repositoryRootPath, 'menus'),
    path.join(CONFIG.repositoryRootPath, 'node_modules'),
    path.join(CONFIG.repositoryRootPath, 'package.json'),
    path.join(CONFIG.repositoryRootPath, 'static'),
    path.join(CONFIG.repositoryRootPath, 'src'),
    path.join(CONFIG.repositoryRootPath, 'vendor')
  ]
  srcPaths = srcPaths.concat(glob.sync(path.join(CONFIG.repositoryRootPath, 'spec', '*.*'), {ignore: path.join('**', '*-spec.*')}))
  for (let srcPath of srcPaths) {
    fs.copySync(srcPath, computeDestinationPath(srcPath), {filter: skipIgnoredPaths})
  }

  console.log(`Copying shell commands to ${CONFIG.intermediateShellCommandsPath}...`);
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'apm', 'node_modules', 'atom-package-manager'),
    path.join(CONFIG.intermediateShellCommandsPath, 'apm'),
    {filter: skipIgnoredPaths}
  )
  if (process.platform !== 'windows') {
    fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(CONFIG.intermediateShellCommandsPath, 'atom.sh'))
  }
}

function computeDestinationPath (srcPath) {
  const relativePath = path.relative(CONFIG.repositoryRootPath, srcPath)
  return path.join(CONFIG.intermediateAppPath, relativePath)
}

function buildIgnoredPathsRegExp () {
  const ignoreRegExps = [
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
