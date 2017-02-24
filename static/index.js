(function () {
  let loadSettings
  const Module = require('module')
  const Path = require('path')
  const vm = require('vm')
  const {remote, ipcRenderer} = require('electron')

  if (typeof snapshotResult !== 'undefined') {
    window.onload = function () {
      process.resourcesPath = Path.normalize(process.resourcesPath)
      process.on('unhandledRejection', function (error, promise) {
        console.error('Unhandled promise rejection %o with error: %o', promise, error)
      })

      loadSettings = remote.getCurrentWindow().loadSettings

      if (!process.env.ATOM_HOME) {
        // Ensure ATOM_HOME is always set before anything else is required
        // This is because of a difference in Linux not inherited between browser and render processes
        // https://github.com/atom/atom/issues/5412
        if (loadSettings && loadSettings.atomHome) {
          process.env.ATOM_HOME = loadSettings.atomHome
        }
      }

      require('../src/crash-reporter-start')({_version: loadSettings.appVersion})

      const entryPointDirPath = __dirname
      Module.prototype.require = function (path) {
        const absoluteFilePath = Module._resolveFilename(path, this, false)
        const relativeFilePath = Path.relative(entryPointDirPath, absoluteFilePath)
        const cachedModule = snapshotResult.customRequire.cache[relativeFilePath]
        return cachedModule ? cachedModule : Module._load(path, this, false)
      }

      snapshotResult.setGlobals(global, process, window, document, require)

      const CSON = snapshotResult.customRequire("../node_modules/season/lib/cson.js")
      CSON.setCacheDir(Path.join(process.env.ATOM_HOME, 'compile-cache', 'cson'))

      const CompileCache = snapshotResult.customRequire('../src/compile-cache.js')
      CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

      const initialize = snapshotResult.customRequire('../src/initialize-application-window.js')
      initialize().then(() => { ipcRenderer.send('window-command', 'window:loaded') })
    }
  }
})()
