'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');
const backupNodeModules = require('./backup-node-modules');
const runApmInstall = require('./run-apm-install');

require('colors');

module.exports = function() {
  console.log(
    `Transpiling packages with custom transpiler configurations in ${
      CONFIG.intermediateAppPath
    }`
  );
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    const rootPackagePath = path.join(
      CONFIG.repositoryRootPath,
      'node_modules',
      packageName
    );
    const intermediatePackagePath = path.join(
      CONFIG.intermediateAppPath,
      'node_modules',
      packageName
    );

    const metadataPath = path.join(intermediatePackagePath, 'package.json');
    const metadata = require(metadataPath);

    if (metadata.atomTranspilers) {
      console.log(' transpiling for package '.cyan + packageName.cyan);
      const rootPackageBackup = backupNodeModules(rootPackagePath);
      const intermediatePackageBackup = backupNodeModules(
        intermediatePackagePath
      );

      // Run `apm install` in the *root* package's path, so we get devDeps w/o apm's weird caching
      // Then copy this folder into the intermediate package's path so we can run the transpilation in-line.
      runApmInstall(rootPackagePath);
      if (fs.existsSync(intermediatePackageBackup.nodeModulesPath)) {
        fs.removeSync(intermediatePackageBackup.nodeModulesPath);
      }
      fs.copySync(
        rootPackageBackup.nodeModulesPath,
        intermediatePackageBackup.nodeModulesPath
      );

      CompileCache.addTranspilerConfigForPath(
        intermediatePackagePath,
        metadata.name,
        metadata,
        metadata.atomTranspilers
      );
      for (let config of metadata.atomTranspilers) {
        const pathsToCompile = glob.sync(
          path.join(intermediatePackagePath, config.glob),
          { nodir: true }
        );
        pathsToCompile.forEach(transpilePath);
      }

      // Now that we've transpiled everything in-place, we no longer want Atom to try to transpile
      // the same files when they're being required.
      delete metadata.atomTranspilers;
      fs.writeFileSync(
        metadataPath,
        JSON.stringify(metadata, null, '  '),
        'utf8'
      );

      CompileCache.removeTranspilerConfigForPath(intermediatePackagePath);
      rootPackageBackup.restore();
      intermediatePackageBackup.restore();
    }
  }
};

function transpilePath(path) {
  fs.writeFileSync(
    path,
    CompileCache.addPathToCache(path, CONFIG.atomHomeDirPath)
  );
}
