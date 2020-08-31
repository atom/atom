const path = require('path');
const electron = require('electron');

const dirname = path.dirname;
path.dirname = function(path) {
  if (typeof path !== 'string') {
    path = '' + path;
    const Grim = require('grim');
    Grim.deprecate('Argument to `path.dirname` must be a string');
  }

  return dirname(path);
};

const extname = path.extname;
path.extname = function(path) {
  if (typeof path !== 'string') {
    path = '' + path;
    const Grim = require('grim');
    Grim.deprecate('Argument to `path.extname` must be a string');
  }

  return extname(path);
};

const basename = path.basename;
path.basename = function(path, ext) {
  if (
    typeof path !== 'string' ||
    (ext !== undefined && typeof ext !== 'string')
  ) {
    path = '' + path;
    const Grim = require('grim');
    Grim.deprecate('Arguments to `path.basename` must be strings');
  }

  return basename(path, ext);
};

electron.ipcRenderer.sendChannel = function() {
  const Grim = require('grim');
  Grim.deprecate('Use `ipcRenderer.send` instead of `ipcRenderer.sendChannel`');
  return this.send.apply(this, arguments);
};

const remoteRequire = electron.remote.require;
electron.remote.require = function(moduleName) {
  const Grim = require('grim');
  switch (moduleName) {
    case 'menu':
      Grim.deprecate('Use `remote.Menu` instead of `remote.require("menu")`');
      return this.Menu;
    case 'menu-item':
      Grim.deprecate(
        'Use `remote.MenuItem` instead of `remote.require("menu-item")`'
      );
      return this.MenuItem;
    case 'browser-window':
      Grim.deprecate(
        'Use `remote.BrowserWindow` instead of `remote.require("browser-window")`'
      );
      return this.BrowserWindow;
    case 'dialog':
      Grim.deprecate(
        'Use `remote.Dialog` instead of `remote.require("dialog")`'
      );
      return this.Dialog;
    case 'app':
      Grim.deprecate('Use `remote.app` instead of `remote.require("app")`');
      return this.app;
    case 'crash-reporter':
      Grim.deprecate(
        'Use `remote.crashReporter` instead of `remote.require("crashReporter")`'
      );
      return this.crashReporter;
    case 'global-shortcut':
      Grim.deprecate(
        'Use `remote.globalShortcut` instead of `remote.require("global-shortcut")`'
      );
      return this.globalShortcut;
    case 'clipboard':
      Grim.deprecate(
        'Use `remote.clipboard` instead of `remote.require("clipboard")`'
      );
      return this.clipboard;
    case 'native-image':
      Grim.deprecate(
        'Use `remote.nativeImage` instead of `remote.require("native-image")`'
      );
      return this.nativeImage;
    case 'tray':
      Grim.deprecate('Use `remote.Tray` instead of `remote.require("tray")`');
      return this.Tray;
    default:
      return remoteRequire.call(this, moduleName);
  }
};
