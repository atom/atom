(function() {
  // Define the window start time before the requires so we get a more accurate
  // window:start marker.
  const startWindowTime = Date.now();

  const electron = require('electron');
  const path = require('path');
  const Module = require('module');
  const getWindowLoadSettings = require('../src/get-window-load-settings');
  const getReleaseChannel = require('../src/get-release-channel');
  const StartupTime = require('../src/startup-time');
  const entryPointDirPath = __dirname;
  let blobStore = null;
  let useSnapshot = false;

  const startupMarkers = electron.remote.getCurrentWindow().startupMarkers;

  if (startupMarkers) {
    StartupTime.importData(startupMarkers);
  }
  StartupTime.addMarker('window:start', startWindowTime);

  window.onload = function() {
    try {
      StartupTime.addMarker('window:onload:start');
      const startTime = Date.now();

      process.on('unhandledRejection', function(error, promise) {
        console.error(
          'Unhandled promise rejection %o with error: %o',
          promise,
          error
        );
      });

      // Normalize to make sure drive letter case is consistent on Windows
      process.resourcesPath = path.normalize(process.resourcesPath);

      setupAtomHome();
      const devMode =
        getWindowLoadSettings().devMode ||
        !getWindowLoadSettings().resourcePath.startsWith(
          process.resourcesPath + path.sep
        );
      useSnapshot = !devMode && typeof snapshotResult !== 'undefined';

      if (devMode) {
        const metadata = require('../package.json');
        if (!metadata._deprecatedPackages) {
          try {
            metadata._deprecatedPackages = require('../script/deprecated-packages.json');
          } catch (requireError) {
            console.error(
              'Failed to setup deprecated packages list',
              requireError.stack
            );
          }
        }
      } else if (useSnapshot) {
        Module.prototype.require = function(module) {
          const absoluteFilePath = Module._resolveFilename(module, this, false);
          let relativeFilePath = path.relative(
            entryPointDirPath,
            absoluteFilePath
          );
          if (process.platform === 'win32') {
            relativeFilePath = relativeFilePath.replace(/\\/g, '/');
          }
          let cachedModule =
            snapshotResult.customRequire.cache[relativeFilePath];
          if (!cachedModule) {
            cachedModule = { exports: Module._load(module, this, false) };
            snapshotResult.customRequire.cache[relativeFilePath] = cachedModule;
          }
          return cachedModule.exports;
        };

        snapshotResult.setGlobals(
          global,
          process,
          window,
          document,
          console,
          require
        );
      }

      const FileSystemBlobStore = useSnapshot
        ? snapshotResult.customRequire('../src/file-system-blob-store.js')
        : require('../src/file-system-blob-store');
      blobStore = FileSystemBlobStore.load(
        path.join(process.env.ATOM_HOME, 'blob-store')
      );

      const NativeCompileCache = useSnapshot
        ? snapshotResult.customRequire('../src/native-compile-cache.js')
        : require('../src/native-compile-cache');
      NativeCompileCache.setCacheStore(blobStore);
      NativeCompileCache.setV8Version(process.versions.v8);
      NativeCompileCache.install();

      if (getWindowLoadSettings().profileStartup) {
        profileStartup(Date.now() - startTime);
      } else {
        StartupTime.addMarker('window:setup-window:start');
        setupWindow().then(() => {
          StartupTime.addMarker('window:setup-window:end');
        });
        setLoadTime(Date.now() - startTime);
      }
    } catch (error) {
      handleSetupError(error);
    }
    StartupTime.addMarker('window:onload:end');
  };

  function setLoadTime(loadTime) {
    if (global.atom) {
      global.atom.loadTime = loadTime;
    }
  }

  function handleSetupError(error) {
    const currentWindow = electron.remote.getCurrentWindow();
    currentWindow.setSize(800, 600);
    currentWindow.center();
    currentWindow.show();
    currentWindow.openDevTools();
    console.error(error.stack || error);
  }

  function setupWindow() {
    const CompileCache = useSnapshot
      ? snapshotResult.customRequire('../src/compile-cache.js')
      : require('../src/compile-cache');
    CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME);
    CompileCache.install(process.resourcesPath, require);

    const ModuleCache = useSnapshot
      ? snapshotResult.customRequire('../src/module-cache.js')
      : require('../src/module-cache');
    ModuleCache.register(getWindowLoadSettings());

    const startCrashReporter = useSnapshot
      ? snapshotResult.customRequire('../src/crash-reporter-start.js')
      : require('../src/crash-reporter-start');

    useSnapshot
      ? snapshotResult.customRequire(
          '../node_modules/document-register-element/build/document-register-element.node.js'
        )
      : require('document-register-element');

    const Grim = useSnapshot
      ? snapshotResult.customRequire('../node_modules/grim/lib/grim.js')
      : require('grim');
    const documentRegisterElement = document.registerElement;

    document.registerElement = (type, options) => {
      Grim.deprecate(
        'Use `customElements.define` instead of `document.registerElement` see https://javascript.info/custom-elements'
      );

      return documentRegisterElement(type, options);
    };

    const { userSettings, appVersion } = getWindowLoadSettings();
    const uploadToServer =
      userSettings &&
      userSettings.core &&
      userSettings.core.telemetryConsent === 'limited';
    const releaseChannel = getReleaseChannel(appVersion);

    startCrashReporter({
      uploadToServer,
      releaseChannel
    });

    const CSON = useSnapshot
      ? snapshotResult.customRequire('../node_modules/season/lib/cson.js')
      : require('season');
    CSON.setCacheDir(path.join(CompileCache.getCacheDirectory(), 'cson'));

    const initScriptPath = path.relative(
      entryPointDirPath,
      getWindowLoadSettings().windowInitializationScript
    );
    const initialize = useSnapshot
      ? snapshotResult.customRequire(initScriptPath)
      : require(initScriptPath);

    StartupTime.addMarker('window:initialize:start');

    return initialize({ blobStore: blobStore }).then(function() {
      StartupTime.addMarker('window:initialize:end');
      electron.ipcRenderer.send('window-command', 'window:loaded');
    });
  }

  function profileStartup(initialTime) {
    function profile() {
      console.profile('startup');
      const startTime = Date.now();
      setupWindow().then(function() {
        setLoadTime(Date.now() - startTime + initialTime);
        console.profileEnd('startup');
        console.log(
          'Switch to the Profiles tab to view the created startup profile'
        );
      });
    }

    const webContents = electron.remote.getCurrentWindow().webContents;
    if (webContents.devToolsWebContents) {
      profile();
    } else {
      webContents.once('devtools-opened', () => {
        setTimeout(profile, 1000);
      });
      webContents.openDevTools();
    }
  }

  function setupAtomHome() {
    if (process.env.ATOM_HOME) {
      return;
    }

    // Ensure ATOM_HOME is always set before anything else is required
    // This is because of a difference in Linux not inherited between browser and render processes
    // https://github.com/atom/atom/issues/5412
    if (getWindowLoadSettings() && getWindowLoadSettings().atomHome) {
      process.env.ATOM_HOME = getWindowLoadSettings().atomHome;
    }
  }
})();
