module.exports = require('electron').shell;

const Grim = require('grim');
Grim.deprecate('Use `require("electron").shell` instead of `require("shell")`');

// Ensure each package that requires this shim causes a deprecation warning
delete require.cache[__filename];
