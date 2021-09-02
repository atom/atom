'use strict';

const _ = require('underscore-plus');
const crypto = require('crypto');
const path = require('path');

const defaultOptions = {
  target: 1,
  module: 'commonjs',
  sourceMap: true
};

let TypeScriptSimple = null;
let typescriptVersionDir = null;

exports.shouldCompile = function() {
  return true;
};

exports.getCachePath = function(sourceCode) {
  if (typescriptVersionDir == null) {
    const version = require('typescript-simple/package.json').version;
    typescriptVersionDir = path.join(
      'ts',
      createVersionAndOptionsDigest(version, defaultOptions)
    );
  }

  return path.join(
    typescriptVersionDir,
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + '.js'
  );
};

exports.compile = function(sourceCode, filePath) {
  if (!TypeScriptSimple) {
    TypeScriptSimple = require('typescript-simple').TypeScriptSimple;
  }

  if (process.platform === 'win32') {
    filePath = 'file:///' + path.resolve(filePath).replace(/\\/g, '/');
  }

  const options = _.defaults({ filename: filePath }, defaultOptions);
  return new TypeScriptSimple(options, false).compile(sourceCode, filePath);
};

function createVersionAndOptionsDigest(version, options) {
  return crypto
    .createHash('sha1')
    .update('typescript', 'utf8')
    .update('\0', 'utf8')
    .update(version, 'utf8')
    .update('\0', 'utf8')
    .update(JSON.stringify(options), 'utf8')
    .digest('hex');
}
