window.onload = function() {
  try {
    var startTime = Date.now();

    // Skip "?loadSettings=".
    var loadSettings = JSON.parse(decodeURIComponent(location.search.substr(14)));

    // Require before the module cache in dev mode
    if (loadSettings.devMode) {
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

    if (!loadSettings.devMode) {
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
