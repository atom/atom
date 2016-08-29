(function () {
  var path = require('path')
  var FileSystemBlobStore = require('../src/file-system-blob-store')
  var NativeCompileCache = require('../src/native-compile-cache')

  var loadSettings = null
  var loadSettingsError = null
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

      if (loadSettingsError) {
        throw loadSettingsError
      }

      var devMode = loadSettings.devMode || !loadSettings.resourcePath.startsWith(process.resourcesPath + path.sep)

      if (devMode) {
        setupDeprecatedPackages()
      }

      if (loadSettings.profileStartup) {
        profileStartup(loadSettings, Date.now() - startTime)
      } else {
        setupWindow(loadSettings)
        setLoadTime(Date.now() - startTime)
      }
    } catch (error) {
      handleSetupError(error)
    }
  }

  function setLoadTime (loadTime) {
    if (global.atom) {
      global.atom.loadTime = loadTime
      console.log('Window load time: ' + global.atom.getWindowLoadTime() + 'ms')
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

  function setupWindow (loadSettings) {
    var CompileCache = require('../src/compile-cache')
    CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

    var ModuleCache = require('../src/module-cache')
    ModuleCache.register(loadSettings)
    ModuleCache.add(loadSettings.resourcePath)

    // By explicitly passing the app version here, we could save the call
    // of "require('remote').require('app').getVersion()".
    var startCrashReporter = require('../src/crash-reporter-start')
    startCrashReporter({_version: loadSettings.appVersion})

    setupVmCompatibility()
    setupCsonCache(CompileCache.getCacheDirectory())

    var initialize = require(loadSettings.windowInitializationScript)
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

  function profileStartup (loadSettings, initialTime) {
    function profile () {
      console.profile('startup')
      var startTime = Date.now()
      setupWindow(loadSettings).then(function () {
        setLoadTime(Date.now() - startTime + initialTime)
        console.profileEnd('startup')
        console.log('Switch to the Profiles tab to view the created startup profile')
      })
    }

    var currentWindow = require('electron').remote.getCurrentWindow()
    if (currentWindow.devToolsWebContents) {
      profile()
    } else {
      currentWindow.openDevTools()
      currentWindow.once('devtools-opened', function () {
        setTimeout(profile, 1000)
      })
    }
  }

  function parseLoadSettings () {
    var rawLoadSettings = decodeURIComponent(window.location.hash.substr(1))
    try {
      loadSettings = JSON.parse(rawLoadSettings)
    } catch (error) {
      console.error('Failed to parse load settings: ' + rawLoadSettings)
      loadSettingsError = error
    }
  }

  var setupAtomHome = function () {
    if (process.env.ATOM_HOME) {
      return
    }

    // Ensure ATOM_HOME is always set before anything else is required
    // This is because of a difference in Linux not inherited between browser and render processes
    // https://github.com/atom/atom/issues/5412
    if (loadSettings && loadSettings.atomHome) {
      process.env.ATOM_HOME = loadSettings.atomHome
    }
  }

  parseLoadSettings()
  setupAtomHome()
})()
