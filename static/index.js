window.onload = function() {
  var ipc = require('ipc');
  try {
    // Skip "?loadSettings=".
    var loadSettings = JSON.parse(decodeURIComponent(location.search.substr(14)));

    // Start the crash reporter before anything else.
    require('crash-reporter').start({
      productName: 'Atom',
      companyName: 'GitHub',
      // By explicitly passing the app version here, we could save the call
      // of "require('remote').require('app').getVersion()".
      extra: {_version: loadSettings.appVersion}
    });

    require('vm-compatibility-layer');
    require('coffee-script').register();
    require('../src/coffee-cache')).register();

    ModuleCache = require('../src/module-cache');
    ModuleCache.add(loadSettings.resourcePath);
    ModuleCache.register();

    require(loadSettings.bootstrapScript);
    ipc.sendChannel('window-command', 'window:loaded')
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
