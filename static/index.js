function registerRuntimeTranspilers() {
  // This sets require.extensions['.coffee'].
  require('coffee-script').register();

  // This redefines require.extensions['.js'].
  require('../src/6to5').register();
}

window.onload = function() {
  try {
    var startTime = Date.now();

    var fs = require('fs');
    var path = require('path');

    // Ensure ATOM_HOME is always set before anything else is required
    if (!process.env.ATOM_HOME) {
      var home;
      if (process.platform === 'win32') {
        home = process.env.USERPROFILE;
      } else {
        home = process.env.HOME;
      }
      var atomHome = path.join(home, '.atom');
      try {
        atomHome = fs.realpathSync(atomHome);
      } catch (error) {
        // Ignore since the path might just not exist yet.
      }
      process.env.ATOM_HOME = atomHome;
    }

    // Skip "?loadSettings=".
    var rawLoadSettings = decodeURIComponent(location.search.substr(14));
    var loadSettings;
    try {
      loadSettings = JSON.parse(rawLoadSettings);
    } catch (error) {
      console.error("Failed to parse load settings: " + rawLoadSettings);
      throw error;
    }

    // Normalize to make sure drive letter case is consistent on Windows
    process.resourcesPath = path.normalize(process.resourcesPath);

    var devMode = loadSettings.devMode || !loadSettings.resourcePath.startsWith(process.resourcesPath + path.sep);

    // Require before the module cache in dev mode
    if (devMode) {
      registerRuntimeTranspilers();
    }

    ModuleCache = require('../src/module-cache');
    ModuleCache.register(loadSettings);
    ModuleCache.add(loadSettings.resourcePath);

    // Start the crash reporter before anything else.
    require('crash-reporter').start({
      productName: 'Atom',
      companyName: 'GitHub',
      // By explicitly passing the app version here, we could save the call
      // of "require('remote').require('app').getVersion()".
      extra: {_version: loadSettings.appVersion}
    });

    require('vm-compatibility-layer');

    if (!devMode) {
      registerRuntimeTranspilers();
    }

    require('../src/coffee-cache').register();

    require(loadSettings.bootstrapScript);
    require('ipc').sendChannel('window-command', 'window:loaded');

    if (global.atom) {
      global.atom.loadTime = Date.now() - startTime;
      console.log('Window load time: ' + global.atom.getWindowLoadTime() + 'ms');
    }
  }
  catch (error) {
    var currentWindow = require('remote').getCurrentWindow();
    currentWindow.setSize(800, 600);
    currentWindow.center();
    currentWindow.show();
    currentWindow.openDevTools();
    console.error(error.stack || error);
  }
}
