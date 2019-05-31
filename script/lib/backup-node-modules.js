const fs = require('fs-extra');
const path = require('path');

module.exports = function(packagePath) {
  const nodeModulesPath = path.join(packagePath, 'node_modules');
  const nodeModulesBackupPath = path.join(packagePath, 'node_modules.bak');

  if (fs.existsSync(nodeModulesBackupPath)) {
    throw new Error(
      'Cannot back up ' +
        nodeModulesPath +
        '; ' +
        nodeModulesBackupPath +
        ' already exists'
    );
  }

  // some packages may have no node_modules after deduping, but we still want
  // to "back-up" and later restore that fact
  if (!fs.existsSync(nodeModulesPath)) {
    const msg =
      'Skipping backing up ' + nodeModulesPath + ' as it does not exist';
    console.log(msg.gray);

    const restore = function stubRestoreNodeModules() {
      if (fs.existsSync(nodeModulesPath)) {
        fs.removeSync(nodeModulesPath);
      }
    };

    return { restore, nodeModulesPath, nodeModulesBackupPath };
  }

  fs.copySync(nodeModulesPath, nodeModulesBackupPath);

  const restore = function restoreNodeModules() {
    if (!fs.existsSync(nodeModulesBackupPath)) {
      throw new Error(
        'Cannot restore ' +
          nodeModulesPath +
          '; ' +
          nodeModulesBackupPath +
          ' does not exist'
      );
    }

    if (fs.existsSync(nodeModulesPath)) {
      fs.removeSync(nodeModulesPath);
    }
    fs.renameSync(nodeModulesBackupPath, nodeModulesPath);
  };

  return { restore, nodeModulesPath, nodeModulesBackupPath };
};
