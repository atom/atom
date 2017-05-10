const childProcess = require('child_process')
const fs = require('fs')
const path = require('path')
const electronLink = require('electron-link')
const CONFIG = require('../config')
const vm = require('vm')

module.exports = function (packagedAppPath) {
  const snapshotScriptPath = path.join(CONFIG.buildOutputPath, 'startup.js')
  const coreModules = new Set(['electron', 'atom', 'shell', 'WNdb', 'lapack', 'remote'])
  const baseDirPath = path.join(CONFIG.intermediateAppPath, 'static')
  let processedFiles = 0

  return electronLink({
    baseDirPath,
    mainPath: path.resolve(baseDirPath, '..', 'src', 'initialize-application-window.js'),
    cachePath: path.join(CONFIG.atomHomeDirPath, 'snapshot-cache'),
    auxiliaryData: CONFIG.snapshotAuxiliaryData,
    shouldExcludeModule: (modulePath) => {
      if (processedFiles > 0) {
        process.stdout.write('\r')
      }
      process.stdout.write(`Generating snapshot script at "${snapshotScriptPath}" (${++processedFiles})`)

      const relativePath = path.relative(baseDirPath, modulePath)
      return (
        modulePath.endsWith('.node') ||
        coreModules.has(modulePath) ||
        (relativePath.startsWith(path.join('..', 'src')) && relativePath.endsWith('-element.js')) ||
        relativePath.startsWith(path.join('..', 'node_modules', 'dugite')) ||
        relativePath == path.join('..', 'exports', 'atom.js') ||
        relativePath == path.join('..', 'src', 'electron-shims.js') ||
        relativePath == path.join('..', 'src', 'safe-clipboard.js') ||
        relativePath == path.join('..', 'node_modules', 'atom-keymap', 'lib', 'command-event.js') ||
        relativePath == path.join('..', 'node_modules', 'babel-core', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'cached-run-in-this-context', 'lib', 'main.js') ||
        relativePath == path.join('..', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('..', 'node_modules', 'cson-parser', 'node_modules', 'coffee-script', 'lib', 'coffee-script', 'register.js') ||
        relativePath == path.join('..', 'node_modules', 'decompress-zip', 'lib', 'decompress-zip.js') ||
        relativePath == path.join('..', 'node_modules', 'debug', 'node.js') ||
        relativePath == path.join('..', 'node_modules', 'fs-extra', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'git-utils', 'lib', 'git.js') ||
        relativePath == path.join('..', 'node_modules', 'glob', 'glob.js') ||
        relativePath == path.join('..', 'node_modules', 'graceful-fs', 'graceful-fs.js') ||
        relativePath == path.join('..', 'node_modules', 'htmlparser2', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'markdown-preview', 'node_modules', 'htmlparser2', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'roaster', 'node_modules', 'htmlparser2', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'task-lists', 'node_modules', 'htmlparser2', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'iconv-lite', 'encodings', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'lib', 'less', 'fs.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'lib', 'less-node', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'less', 'node_modules', 'graceful-fs', 'graceful-fs.js') ||
        relativePath == path.join('..', 'node_modules', 'minimatch', 'minimatch.js') ||
        relativePath == path.join('..', 'node_modules', 'node-fetch', 'lib', 'fetch-error.js') ||
        relativePath == path.join('..', 'node_modules', 'nsfw', 'node_modules', 'fs-extra', 'lib', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'superstring', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'oniguruma', 'src', 'oniguruma.js') ||
        relativePath == path.join('..', 'node_modules', 'request', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'resolve', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'resolve', 'lib', 'core.js') ||
        relativePath == path.join('..', 'node_modules', 'scandal', 'node_modules', 'minimatch', 'minimatch.js') ||
        relativePath == path.join('..', 'node_modules', 'settings-view', 'node_modules', 'glob', 'glob.js') ||
        relativePath == path.join('..', 'node_modules', 'settings-view', 'node_modules', 'minimatch', 'minimatch.js') ||
        relativePath == path.join('..', 'node_modules', 'spellchecker', 'lib', 'spellchecker.js') ||
        relativePath == path.join('..', 'node_modules', 'spelling-manager', 'node_modules', 'natural', 'lib', 'natural', 'index.js') ||
        relativePath == path.join('..', 'node_modules', 'tar', 'tar.js') ||
        relativePath == path.join('..', 'node_modules', 'temp', 'lib', 'temp.js') ||
        relativePath == path.join('..', 'node_modules', 'tmp', 'lib', 'tmp.js') ||
        relativePath == path.join('..', 'node_modules', 'tree-view', 'node_modules', 'minimatch', 'minimatch.js')
      )
    }
  }).then((snapshotScript) => {
    fs.writeFileSync(snapshotScriptPath, snapshotScript)
    process.stdout.write('\n')

    console.log('Verifying if snapshot can be executed via `mksnapshot`')
    vm.runInNewContext(snapshotScript, undefined, {filename: snapshotScriptPath, displayErrors: true})

    const generatedStartupBlobPath = path.join(CONFIG.buildOutputPath, 'snapshot_blob.bin')
    console.log(`Generating startup blob at "${generatedStartupBlobPath}"`)
    childProcess.execFileSync(
      path.join(CONFIG.repositoryRootPath, 'script', 'node_modules', 'electron-mksnapshot', 'bin', 'mksnapshot'),
      [snapshotScriptPath, '--startup_blob', generatedStartupBlobPath]
    )

    let startupBlobDestinationPath
    if (process.platform === 'darwin') {
      startupBlobDestinationPath = `${packagedAppPath}/Contents/Frameworks/Electron Framework.framework/Resources/snapshot_blob.bin`
    } else {
      startupBlobDestinationPath = path.join(packagedAppPath, 'snapshot_blob.bin')
    }

    console.log(`Moving generated startup blob into "${startupBlobDestinationPath}"`)
    fs.unlinkSync(startupBlobDestinationPath)
    fs.renameSync(generatedStartupBlobPath, startupBlobDestinationPath)
  })
}
