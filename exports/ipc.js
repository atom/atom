module.exports = require('electron').ipcRenderer;

const Grim = require('grim');
Grim.deprecate(
  'Use `require("electron").ipcRenderer` instead of `require("ipc")`'
);

// Ensure each package that requires this shim causes a deprecation warning
delete require.cache[__filename];
