const { protocol } = require('electron');
const fs = require('fs-plus');
const path = require('path');

// Handles requests with 'atom' protocol.
//
// It's created by {AtomApplication} upon instantiation and is used to create a
// custom resource loader for 'atom://' URLs.
//
// The following directories are searched in order:
//   * ~/.atom/assets
//   * ~/.atom/dev/packages (unless in safe mode)
//   * ~/.atom/packages
//   * RESOURCE_PATH/node_modules
//
module.exports = class AtomProtocolHandler {
  constructor(resourcePath, safeMode) {
    this.loadPaths = [];

    if (!safeMode) {
      this.loadPaths.push(path.join(process.env.ATOM_HOME, 'dev', 'packages'));
      this.loadPaths.push(path.join(resourcePath, 'packages'));
    }

    this.loadPaths.push(path.join(process.env.ATOM_HOME, 'packages'));
    this.loadPaths.push(path.join(resourcePath, 'node_modules'));

    this.registerAtomProtocol();
  }

  // Creates the 'atom' custom protocol handler.
  registerAtomProtocol() {
    protocol.registerFileProtocol('atom', (request, callback) => {
      const relativePath = path.normalize(request.url.substr(7));

      let filePath;
      if (relativePath.indexOf('assets/') === 0) {
        const assetsPath = path.join(process.env.ATOM_HOME, relativePath);
        const stat = fs.statSyncNoException(assetsPath);
        if (stat && stat.isFile()) filePath = assetsPath;
      }

      if (!filePath) {
        for (let loadPath of this.loadPaths) {
          filePath = path.join(loadPath, relativePath);
          const stat = fs.statSyncNoException(filePath);
          if (stat && stat.isFile()) break;
        }
      }

      callback(filePath);
    });
  }
};
