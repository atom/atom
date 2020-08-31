'use strict';

const peg = require('pegjs');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');

module.exports = function() {
  console.log(`Transpiling PEG.js paths in ${CONFIG.intermediateAppPath}`);
  for (let path of getPathsToTranspile()) {
    transpilePegJsPath(path);
  }
};

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
          '*.pegjs'
        ),
        { nodir: true }
      )
    );
  }
  return paths;
}

function transpilePegJsPath(pegJsPath) {
  const inputCode = fs.readFileSync(pegJsPath, 'utf8');
  const jsPath = pegJsPath.replace(/pegjs$/g, 'js');
  const outputCode =
    'module.exports = ' + peg.buildParser(inputCode, { output: 'source' });
  fs.writeFileSync(jsPath, outputCode);
  fs.unlinkSync(pegJsPath);
}
