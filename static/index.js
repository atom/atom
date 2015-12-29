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
    var currentWindow = require('remote').getCurrentWindow()
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

    // Start the crash reporter before anything else.
    require('crash-reporter').start({
      productName: 'Atom',
      companyName: 'GitHub',
      // By explicitly passing the app version here, we could save the call
      // of "require('remote').require('app').getVersion()".
      extra: {_version: loadSettings.appVersion}
    })

    setupVmCompatibility()
    setupCsonCache(CompileCache.getCacheDirectory())

    var initialize = require(loadSettings.windowInitializationScript)
    initialize({blobStore: blobStore})
    require('ipc').sendChannel('window-command', 'window:loaded')
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
        metadata._deprecatedPackages = require('../build/deprecated-packages.json')
      } catch(requireError) {
        console.error('Failed to setup deprecated packages list', requireError.stack)
      }
    }
  }

  function profileStartup (loadSettings, initialTime) {
    function profile () {
      console.profile('startup')
      try {
        var startTime = Date.now()
        setupWindow(loadSettings)
        setLoadTime(Date.now() - startTime + initialTime)
      } catch (error) {
        handleSetupError(error)
      } finally {
        console.profileEnd('startup')
        console.log('Switch to the Profiles tab to view the created startup profile')
      }
    }

    var currentWindow = require('remote').getCurrentWindow()
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

  function setupWindowBackground () {
    if (loadSettings && loadSettings.isSpec) {
      return
    }

    var backgroundColor = window.localStorage.getItem('atom:window-background-color')
    if (!backgroundColor) {
      return
    }

    var backgroundStylesheet = document.createElement('style')
    backgroundStylesheet.type = 'text/css'
    backgroundStylesheet.innerText = 'html, body { background: ' + backgroundColor + ' !important; }'
    document.head.appendChild(backgroundStylesheet)

    // Remove once the page loads
    window.addEventListener('load', function loadWindow () {
      window.removeEventListener('load', loadWindow, false)
      setTimeout(function () {
        backgroundStylesheet.remove()
        backgroundStylesheet = null
      }, 1000)
    }, false)
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
  setupWindowBackground()
})()
