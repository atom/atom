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
  // https://github.com/electron-userland/electron-packager/blob/master/docs/api.md
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
  const ignoredPaths = [
    '.DS_Store',
    '.jshintrc',
    '.npmignore',
    '.pairs',
    '.travis.yml',
    'appveyor.yml',
    '.idea',
    '.editorconfig',
    '.lint',
    '.lintignore',
    '.eslintrc',
    '.jshintignore',
    'coffeelint.json',
    '.coffeelintignore',
    '.gitattributes',
    '.gitkeep',
    path.join('git-utils', 'deps'),
    path.join('oniguruma', 'deps'),
    path.join('less', 'dist'),
    path.join('npm', 'doc'),
    path.join('npm', 'html'),
    path.join('npm', 'man'),
    path.join('npm', 'node_modules', '.bin', 'beep'),
    path.join('npm', 'node_modules', '.bin', 'clear'),
    path.join('npm', 'node_modules', '.bin', 'starwars'),
    path.join('pegjs', 'examples'),
    path.join('get-parameter-names', 'node_modules', 'testla'),
    path.join('get-parameter-names', 'node_modules', '.bin', 'testla'),
    path.join('jasmine-reporters', 'ext'),
    path.join('jasmine-node', 'node_modules', 'gaze'),
    path.join('jasmine-node', 'spec'),
    path.join('node_modules', 'nan'),
    path.join('node_modules', 'native-mate'),
    path.join('build', 'binding.Makefile'),
    path.join('build', 'config.gypi'),
    path.join('build', 'gyp-mac-tool'),
    path.join('build', 'Makefile'),
    path.join('build', 'Release', 'obj.target'),
    path.join('build', 'Release', 'obj'),
    path.join('build', 'Release', '.deps'),
    path.join('vendor', 'apm'),

    // These are only required in dev-mode, when pegjs grammars aren't precompiled
    path.join('snippets', 'node_modules', 'loophole'),
    path.join('snippets', 'node_modules', 'pegjs'),
    path.join('snippets', 'node_modules', '.bin', 'pegjs'),
  ]

  const regExpSource = ignoredPaths.map(path => '(' + escapeRegExp(path) + ')').join('|')
  return new RegExp(regExpSource)
}

function escapeRegExp (string) {
  string.replace(/[.?*+^$[\]\\(){}|-]/g, "\\$&")
}
