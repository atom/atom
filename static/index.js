(function () {
  var path = require('path')
  var FileSystemBlobStore = require('../src/file-system-blob-store')
  var NativeCompileCache = require('../src/native-compile-cache')
  var getWindowLoadSettings = require('../src/get-window-load-settings')

  var blobStore = null

  window.onload = function () {
    try {
      var startTime = Date.now()

      process.on('unhandledRejection', function (error, promise) {
        console.error('Unhandled promise rejection %o with error: %o', promise, error)
      })

      blobStore = FileSystemBlobStore.load(
        path.join(process.env.ATOM_HOME, 'blob-store/')
      )
      NativeCompileCache.setCacheStore(blobStore)
      NativeCompileCache.setV8Version(process.versions.v8)
      NativeCompileCache.install()

      // Normalize to make sure drive letter case is consistent on Windows
      process.resourcesPath = path.normalize(process.resourcesPath)

      var devMode = getWindowLoadSettings().devMode || !getWindowLoadSettings().resourcePath.startsWith(process.resourcesPath + path.sep)

      if (devMode) {
        setupDeprecatedPackages()
      }

      if (getWindowLoadSettings().profileStartup) {
        profileStartup(Date.now() - startTime)
      } else {
        setupWindow()
        setLoadTime(Date.now() - startTime)
      }
    } catch (error) {
      handleSetupError(error)
    }
  }

  function setLoadTime (loadTime) {
    if (global.atom) {
      global.atom.loadTime = loadTime
    }
  }

  function handleSetupError (error) {
    var currentWindow = require('electron').remote.getCurrentWindow()
    currentWindow.setSize(800, 600)
    currentWindow.center()
    currentWindow.show()
    currentWindow.openDevTools()
    console.error(error.stack || error)
  }

  function setupWindow () {
    var CompileCache = require('../src/compile-cache')
    CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

    var ModuleCache = require('../src/module-cache')
    ModuleCache.register(getWindowLoadSettings())
    ModuleCache.add(getWindowLoadSettings().resourcePath)

    // By explicitly passing the app version here, we could save the call
    // of "require('remote').require('app').getVersion()".
    var startCrashReporter = require('../src/crash-reporter-start')
    startCrashReporter({_version: getWindowLoadSettings().appVersion})

    setupVmCompatibility()
    setupCsonCache(CompileCache.getCacheDirectory())

    var initialize = require(getWindowLoadSettings().windowInitializationScript)
    return initialize({blobStore: blobStore}).then(function () {
      require('electron').ipcRenderer.send('window-command', 'window:loaded')
    })
  }

  function setupCsonCache (cacheDir) {
    require('season').setCacheDir(path.join(cacheDir, 'cson'))
  }

  function setupVmCompatibility () {
    var vm = require('vm')
    if (!vm.Script.createContext) {
      vm.Script.createContext = vm.createContext
    }
  }

  function setupDeprecatedPackages () {
    var metadata = require('../package.json')
    if (!metadata._deprecatedPackages) {
      try {
        metadata._deprecatedPackages = require('../script/deprecated-packages.json')
      } catch (requireError) {
        console.error('Failed to setup deprecated packages list', requireError.stack)
      }
    }
  }

  function profileStartup (initialTime) {
    function profile () {
      console.profile('startup')
      var startTime = Date.now()
      setupWindow().then(function () {
        setLoadTime(Date.now() - startTime + initialTime)
        console.profileEnd('startup')
        console.log('Switch to the Profiles tab to view the created startup profile')
      })
    }

    const webContents = require('electron').remote.getCurrentWindow().webContents
    if (webContents.devToolsWebContents) {
      profile()
    } else {
      webContents.once('devtools-opened', () => { setTimeout(profile, 1000) })
      webContents.openDevTools()
    }
  }

  var setupAtomHome = function () {
    if (process.env.ATOM_HOME) {
      return
    }

    // Ensure ATOM_HOME is always set before anything else is required
    // This is because of a difference in Linux not inherited between browser and render processes
    // https://github.com/atom/atom/issues/5412
    if (getWindowLoadSettings() && getWindowLoadSettings().atomHome) {
      process.env.ATOM_HOME = getWindowLoadSettings().atomHome
    }
  }

  setupAtomHome()
})()
