module.exports = require('electron').webFrame;

const Grim = require('grim');
Grim.deprecate(
  'Use `require("electron").webFrame` instead of `require("web-frame")`'
);

// Ensure each package that requires this shim causes a deprecation warning
delete require.cache[__filename];
