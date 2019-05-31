const { app } = require('electron');
const nslog = require('nslog');
const path = require('path');
const temp = require('temp').track();
const parseCommandLine = require('./parse-command-line');
const startCrashReporter = require('../crash-reporter-start');
const atomPaths = require('../atom-paths');
const fs = require('fs');
const CSON = require('season');
const Config = require('../config');
const StartupTime = require('../startup-time');

StartupTime.setStartTime();

module.exports = function start(resourcePath, devResourcePath, startTime) {
  global.shellStartTime = startTime;
  StartupTime.addMarker('main-process:start');

  process.on('uncaughtException', function(error = {}) {
    if (error.message != null) {
      console.log(error.message);
    }

    if (error.stack != null) {
      console.log(error.stack);
    }
  });

  process.on('unhandledRejection', function(error = {}) {
    if (error.message != null) {
      console.log(error.message);
    }

    if (error.stack != null) {
      console.log(error.stack);
    }
  });

  const previousConsoleLog = console.log;
  console.log = nslog;

  app.commandLine.appendSwitch('enable-experimental-web-platform-features');

  const args = parseCommandLine(process.argv.slice(1));
  args.resourcePath = normalizeDriveLetterName(resourcePath);
  args.devResourcePath = normalizeDriveLetterName(devResourcePath);

  atomPaths.setAtomHome(app.getPath('home'));
  atomPaths.setUserData(app);

  const config = getConfig();
  const colorProfile = config.get('core.colorProfile');
  if (colorProfile && colorProfile !== 'default') {
    app.commandLine.appendSwitch('force-color-profile', colorProfile);
  }

  if (handleStartupEventWithSquirrel()) {
    return;
  } else if (args.test && args.mainProcess) {
    app.setPath(
      'userData',
      temp.mkdirSync('atom-user-data-dir-for-main-process-tests')
    );
    console.log = previousConsoleLog;
    app.on('ready', function() {
      const testRunner = require(path.join(
        args.resourcePath,
        'spec/main-process/mocha-test-runner'
      ));
      testRunner(args.pathsToOpen);
    });
    return;
  }

  // NB: This prevents Win10 from showing dupe items in the taskbar
  app.setAppUserModelId('com.squirrel.atom.' + process.arch);

  function addPathToOpen(event, pathToOpen) {
    event.preventDefault();
    args.pathsToOpen.push(pathToOpen);
  }

  function addUrlToOpen(event, urlToOpen) {
    event.preventDefault();
    args.urlsToOpen.push(urlToOpen);
  }

  app.on('open-file', addPathToOpen);
  app.on('open-url', addUrlToOpen);
  app.on('will-finish-launching', startCrashReporter);

  if (args.userDataDir != null) {
    app.setPath('userData', args.userDataDir);
  } else if (args.test || args.benchmark || args.benchmarkTest) {
    app.setPath('userData', temp.mkdirSync('atom-test-data'));
  }

  StartupTime.addMarker('main-process:electron-onready:start');
  app.on('ready', function() {
    StartupTime.addMarker('main-process:electron-onready:end');
    app.removeListener('open-file', addPathToOpen);
    app.removeListener('open-url', addUrlToOpen);
    const AtomApplication = require(path.join(
      args.resourcePath,
      'src',
      'main-process',
      'atom-application'
    ));
    AtomApplication.open(args);
  });
};

function handleStartupEventWithSquirrel() {
  if (process.platform !== 'win32') {
    return false;
  }

  const SquirrelUpdate = require('./squirrel-update');
  const squirrelCommand = process.argv[1];
  return SquirrelUpdate.handleStartupEvent(app, squirrelCommand);
}

function getConfig() {
  const config = new Config();

  let configFilePath;
  if (fs.existsSync(path.join(process.env.ATOM_HOME, 'config.json'))) {
    configFilePath = path.join(process.env.ATOM_HOME, 'config.json');
  } else if (fs.existsSync(path.join(process.env.ATOM_HOME, 'config.cson'))) {
    configFilePath = path.join(process.env.ATOM_HOME, 'config.cson');
  }

  if (configFilePath) {
    const configFileData = CSON.readFileSync(configFilePath);
    config.resetUserSettings(configFileData);
  }

  return config;
}

function normalizeDriveLetterName(filePath) {
  if (process.platform === 'win32' && filePath) {
    return filePath.replace(
      /^([a-z]):/,
      ([driveLetter]) => driveLetter.toUpperCase() + ':'
    );
  } else {
    return filePath;
  }
}
