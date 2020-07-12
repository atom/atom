'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Transpile CSON paths", function() {
  const paths = getPathsToTranspile();
  this.update(`Transpiling ${paths.length} CSON paths in ${CONFIG.intermediateAppPath}`);
  for (let path of paths) {
    transpileCsonPath(path);
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
          '*.cson'
        ),
        {
          ignore: path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            packageName,
            'spec',
            '**',
            '*.cson'
          ),
          nodir: true
        }
      )
    );
  }
  return paths;
}

function transpileCsonPath(csonPath) {
  const jsonPath = csonPath.replace(/cson$/g, 'json');
  fs.writeFileSync(
    jsonPath,
    JSON.stringify(
      CompileCache.addPathToCache(csonPath, CONFIG.atomHomeDirPath)
    )
  );
  fs.unlinkSync(csonPath);
}
