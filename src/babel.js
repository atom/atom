'use strict';

const crypto = require('crypto');
const path = require('path');
const defaultOptions = require('../static/babelrc.json');

let babel = null;
let babelVersionDirectory = null;

const PREFIXES = [
  '/** @babel */',
  '"use babel"',
  "'use babel'",
  '/* @flow */',
  '// @flow'
];

const PREFIX_LENGTH = Math.max.apply(
  Math,
  PREFIXES.map(function(prefix) {
    return prefix.length;
  })
);

exports.shouldCompile = function(sourceCode) {
  const start = sourceCode.substr(0, PREFIX_LENGTH);
  return PREFIXES.some(function(prefix) {
    return start.indexOf(prefix) === 0;
  });
};

exports.getCachePath = function(sourceCode) {
  if (babelVersionDirectory == null) {
    const babelVersion = require('babel-core/package.json').version;
    babelVersionDirectory = path.join(
      'js',
      'babel',
      createVersionAndOptionsDigest(babelVersion, defaultOptions)
    );
  }

  return path.join(
    babelVersionDirectory,
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + '.js'
  );
};

exports.compile = function(sourceCode, filePath) {
  if (!babel) {
    babel = require('babel-core');
    const Logger = require('babel-core/lib/transformation/file/logger');
    const noop = function() {};
    Logger.prototype.debug = noop;
    Logger.prototype.verbose = noop;
  }

  if (process.platform === 'win32') {
    filePath = 'file:///' + path.resolve(filePath).replace(/\\/g, '/');
  }

  const options = { filename: filePath };
  for (const key in defaultOptions) {
    options[key] = defaultOptions[key];
  }
  return babel.transform(sourceCode, options).code;
};

function createVersionAndOptionsDigest(version, options) {
  return crypto
    .createHash('sha1')
    .update('babel-core', 'utf8')
    .update('\0', 'utf8')
    .update(version, 'utf8')
    .update('\0', 'utf8')
    .update(JSON.stringify(options), 'utf8')
    .digest('hex');
}
