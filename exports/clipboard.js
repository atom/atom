module.exports = require('electron').clipboard;

const Grim = require('grim');
Grim.deprecate(
  'Use `require("electron").clipboard` instead of `require("clipboard")`'
);

// Ensure each package that requires this shim causes a deprecation warning
delete require.cache[__filename];
