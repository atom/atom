const fs = require('fs')
const path = require('path')
const electronLink = require('electron-link')
const CONFIG = require('../config')

module.exports = function () {
  const snapshotScriptPath = path.join(CONFIG.buildOutputPath, 'startup.js')
  console.log(`Generating snapshot script at "${snapshotScriptPath}"`)
  const coreModules = new Set([
    'path', 'electron', 'module', 'fs', 'child_process', 'crypto', 'url',
    'atom', 'vm', 'events', 'os', 'assert', 'buffer', 'tty', 'net', 'constants',
    'http', 'https', 'shell', 'querystring', 'zlib', 'stream', 'WNdb', 'lapack'
  ])
  const baseDirPath = path.join(CONFIG.intermediateAppPath, 'static')
  const snapshotScriptContent = electronLink({
    baseDirPath,
    mainPath: path.resolve(baseDirPath, '..', 'src', 'initialize-application-window.js'),
    shouldExcludeModule: (modulePath) => {
      const relativePath = path.relative(baseDirPath, modulePath)
      return (
        modulePath.endsWith('.node') || modulePath === 'buffer-offset-index' ||
        coreModules.has(modulePath) ||
        (relativePath.startsWith(path.join('..', 'src')) && relativePath.endsWith('-element.js')) ||
        relativePath == path.join('..', 'exports', 'atom.js') ||
        relativePath == path.join('..', 'src', 'config-schema.js') ||
        relativePath == path.join('..', 'src', 'electron-shims.js') ||
        relativePath == path.join('..', 'src', 'module-cache.js') ||
        relativePath == path.join('..', 'src', 'safe-clipboard.js') ||
        relativePath == path.join('..', 'node_modules', 'atom-keymap', 'lib', 'command-event.js') ||
        relativePath == path.join('..', 'node_modules', 'atom-keymap', 'lib', 'helpers.js') ||
        relativePath == path.join('..', 'node_modules', 'babel-core', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'clear-cut', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('..', 'node_modules', 'cson-parser', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('..', 'node_modules', 'fs-plus', 'lib', 'fs-plus.js') ||
        relativePath == path.join('..', 'node_modules', 'decompress-zip', 'lib', 'decompress-zip.js') ||
        relativePath == path.join('..', 'node_modules', 'git-utils', 'lib', 'git.js') ||
        relativePath == path.join('..', 'node_modules', 'glob', 'glob.js') ||
        relativePath == path.join('..', 'node_modules', 'htmlparser2', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'lib', 'less', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'lib', 'less', 'fs.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'node_modules', 'graceful-fs', 'graceful-fs.js') ||
        relativePath == path.join('..', 'node_modules', 'marker-index', 'dist', 'native', 'marker-index.js') ||
        relativePath == path.join('..', 'node_modules', 'mime', 'mime.js') ||
        relativePath == path.join('..', 'node_modules', 'oniguruma', 'lib', 'oniguruma.js') ||
        relativePath == path.join('..', 'node_modules', 'pathwatcher', 'lib', 'main.js') ||
        relativePath == path.join('..', 'node_modules', 'request', 'request.js') ||
        relativePath == path.join('..', 'node_modules', 'resolve', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'resolve', 'lib', 'core.js') ||
        relativePath == path.join('..', 'node_modules', 'settings-view', 'node_modules', 'glob', 'glob.js') ||
        relativePath == path.join('..', 'node_modules', 'spellchecker', 'lib', 'spellchecker.js') ||
        relativePath == path.join('..', 'node_modules', 'styleguide', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('..', 'node_modules', 'tar', 'tar.js') ||
        relativePath == path.join('..', 'node_modules', 'text-buffer', 'node_modules', 'pathwatcher', 'lib', 'main.js') ||
        relativePath == path.join('..', 'node_modules', 'temp', 'lib', 'temp.js') ||
        relativePath == path.join('..', 'node_modules', 'tmp', 'lib', 'tmp.js')
      )
    }
  })
  fs.writeFileSync(snapshotScriptPath, snapshotScriptContent)
}
