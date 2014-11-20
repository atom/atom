window.onload = function() {
  try {
    var startTime = Date.now();

    var fs = require('fs');
    var path = require('path');

    // Patch fs.statSyncNoException/fs.lstatSyncNoException to fail for non-strings
    // https://github.com/atom/atom-shell/issues/843
    var statSyncNoException = fs.statSyncNoException;
    var lstatSyncNoException = fs.lstatSyncNoException;
    fs.statSyncNoException = function(pathToStat) {
      if (pathToStat && typeof pathToStat === 'string')
        return statSyncNoException(pathToStat);
      else
        return false;
    };
    fs.lstatSyncNoException = function(pathToStat) {
      if (pathToStat && typeof pathToStat === 'string')
        return lstatSyncNoException(pathToStat);
      else
        return false;
    };

    // Skip "?loadSettings=".
    var loadSettings = JSON.parse(decodeURIComponent(location.search.substr(14)));

    // Normalize to make sure drive letter case is consistent on Windows
    process.resourcesPath = path.normalize(process.resourcesPath);

    var devMode = loadSettings.devMode || !loadSettings.resourcePath.startsWith(process.resourcesPath + path.sep);

    // Require before the module cache in dev mode
    if (devMode) {
      require('coffee-script').register();
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
      require('coffee-script').register();
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
