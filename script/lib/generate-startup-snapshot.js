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
    'http', 'https'
  ])
  const snapshotScriptContent = electronLink({
    baseDirPath: CONFIG.intermediateAppPath,
    mainPath: path.join(CONFIG.intermediateAppPath, 'src', 'initialize-application-window.js'),
    shouldExcludeModule: (modulePath) => {
      const relativePath = path.relative(CONFIG.intermediateAppPath, modulePath)
      return (
        modulePath.endsWith('.node') || modulePath === 'buffer-offset-index' ||
        coreModules.has(modulePath) ||
        (relativePath.startsWith('src' + path.sep) && relativePath.endsWith('-element.js')) ||
        relativePath == path.join('exports', 'atom.js') ||
        relativePath == path.join('src', 'config-schema.js') ||
        relativePath == path.join('src', 'electron-shims.js') ||
        relativePath == path.join('src', 'module-cache.js') ||
        relativePath == path.join('src', 'safe-clipboard.js') ||
        relativePath == path.join('node_modules', 'atom-keymap', 'lib', 'command-event.js') ||
        relativePath == path.join('node_modules', 'babel-core', 'index.js') ||
        relativePath == path.join('node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('node_modules', 'cson-parser', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('node_modules', 'fs-plus', 'lib', 'fs-plus.js') ||
        relativePath == path.join('node_modules', 'git-utils', 'lib', 'git.js') ||
        relativePath == path.join('node_modules', 'less', 'lib', 'less', 'fs.js') ||
        relativePath == path.join('node_modules', 'less', 'node_modules', 'graceful-fs', 'graceful-fs.js') ||
        relativePath == path.join('node_modules', 'marker-index', 'dist', 'native', 'marker-index.js') ||
        relativePath == path.join('node_modules', 'mime', 'mime.js') ||
        relativePath == path.join('node_modules', 'oniguruma', 'lib', 'oniguruma.js') ||
        relativePath == path.join('node_modules', 'pathwatcher', 'lib', 'main.js') ||
        relativePath == path.join('node_modules', 'request', 'request.js') ||
        relativePath == path.join('node_modules', 'resolve', 'index.js') ||
        relativePath == path.join('node_modules', 'resolve', 'lib', 'core.js') ||
        relativePath == path.join('node_modules', 'text-buffer', 'node_modules', 'pathwatcher', 'lib', 'main.js')
      )
    }
  })
  fs.writeFileSync(snapshotScriptPath, snapshotScriptContent)
}
