'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Transpile Babel paths", function() {
  const paths = getPathsToTranspile();
  this.update(`Transpiling ${paths.length} Babel paths in ${CONFIG.intermediateAppPath}`);
  for (const path of paths) {
    transpileBabelPath(path);
  }
});

function getPathsToTranspile() {
  let paths = [];
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(
      glob.sync(
        path.join(
          CONFIG.intermediateAppPath,
          'node_modules',
          packageName,
          '**',
          '*.js'
        ),
        {
          ignore: path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            packageName,
            'spec',
            '**',
            '*.js'
          ),
          nodir: true
        }
      )
    );
  }
  return paths;
}

function transpileBabelPath(path) {
  fs.writeFileSync(
    path,
    CompileCache.addPathToCache(path, CONFIG.atomHomeDirPath)
  );
}
