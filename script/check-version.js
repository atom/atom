#!/usr/bin/env node

var path = require('path');

var getBundledNodeVersion = require('./bundled-node-version')

var bundledNodePath = path.join(__dirname, '..', 'bin', 'node')
if (process.platform === 'win32') {
  bundledNodePath += '.exe'
}

getBundledNodeVersion(bundledNodePath, function(err, bundledVersion) {
  if (err) {
    console.error(err);
    process.exit(1);
  }

  var ourVersion = process.version

  if (ourVersion !== bundledVersion) {
    console.error('System node (' + ourVersion + ') does not match bundled node (' + bundledVersion + ').');
    if (process.platform === 'win32') {
      console.error('Please use `.\\bin\\node.exe` to run node, and use `.\\bin\\npm.cmd` to run npm scripts.')
    } else {
      console.error('Please use `./bin/node` to run node, and use `./bin/npm` to run npm scripts.')
    }
    process.exit(1)
  } else {
    process.exit(0)
  }
});
