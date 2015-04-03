var fs = require('fs');
var path = require('path');

window.onload = function() {
  try {
    var startTime = Date.now();

    // Ensure ATOM_HOME is always set before anything else is required
    setupAtomHome();

    var cacheDir = path.join(process.env.ATOM_HOME, 'compile-cache');
    // Use separate compile cache when sudo'ing as root to avoid permission issues
    if (process.env.USER === 'root' && process.env.SUDO_USER && process.env.SUDO_USER !== process.env.USER) {
      cacheDir = path.join(cacheDir, 'root');
    }

    var rawLoadSettings = decodeURIComponent(location.hash.substr(1));
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

    setupCoffeeCache(cacheDir);

    ModuleCache = require('../src/module-cache');
    ModuleCache.register(loadSettings);
    ModuleCache.add(loadSettings.resourcePath);

    require('grim').includeDeprecatedAPIs = !loadSettings.apiPreviewMode;

    // Start the crash reporter before anything else.
    require('crash-reporter').start({
      productName: 'Atom',
      companyName: 'GitHub',
      // By explicitly passing the app version here, we could save the call
      // of "require('remote').require('app').getVersion()".
      extra: {_version: loadSettings.appVersion}
    });

    setupVmCompatibility();
    setupCsonCache(cacheDir);
    setupSourceMapCache(cacheDir);
    setupBabel(cacheDir);
    setupTypeScript(cacheDir);

    require(loadSettings.bootstrapScript);
    require('ipc').sendChannel('window-command', 'window:loaded');

    if (global.atom) {
      global.atom.loadTime = Date.now() - startTime;
      console.log('Window load time: ' + global.atom.getWindowLoadTime() + 'ms');
    }
  } catch (error) {
    var currentWindow = require('remote').getCurrentWindow();
    currentWindow.setSize(800, 600);
    currentWindow.center();
    currentWindow.show();
    currentWindow.openDevTools();
    console.error(error.stack || error);
  }
}

var setupCoffeeCache = function(cacheDir) {
  var CoffeeCache = require('coffee-cash');
  CoffeeCache.setCacheDirectory(path.join(cacheDir, 'coffee'));
  CoffeeCache.register();
}

var setupAtomHome = function() {
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
}

var setupBabel = function(cacheDir) {
  var babel = require('../src/babel');
  babel.setCacheDirectory(path.join(cacheDir, 'js', 'babel'));
  babel.register();
}

var setupTypeScript = function(cacheDir) {
  var typescript = require('../src/typescript');
  typescript.setCacheDirectory(path.join(cacheDir, 'typescript'));
  typescript.register();
}

var setupCsonCache = function(cacheDir) {
  require('season').setCacheDir(path.join(cacheDir, 'cson'));
}

var setupSourceMapCache = function(cacheDir) {
  require('coffeestack').setCacheDirectory(path.join(cacheDir, 'coffee', 'source-maps'));
}

var setupVmCompatibility = function() {
  var vm = require('vm');
  if (!vm.Script.createContext)
    vm.Script.createContext = vm.createContext;
}
