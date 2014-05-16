#!/usr/bin/env node
var fs = require('fs');
var mv = require('mv');
var zlib = require('zlib');
var path = require('path');
var request = require('request');
var tar = require('tar');
var temp = require('temp');

temp.track();

var downloadFileToLocation = function(url, filename, callback) {
  var stream = fs.createWriteStream(filename);
  stream.on('end', callback);
  stream.on('error', callback);
  return request(url).pipe(stream);
};

var downloadTarballAndExtract = function(url, location, callback) {
  var tempPath = temp.mkdirSync('apm-node-');
  var stream = tar.Extract({
    path: tempPath
  });
  stream.on('end', callback.bind(this, tempPath));
  stream.on('error', callback);
  var requestOptions = {
    url: url,
    proxy: process.env.http_proxy || process.env.https_proxy
  };
  return request(requestOptions).pipe(zlib.createGunzip()).pipe(stream);
};

var copyNodeBinToLocation = function(callback, version, targetFilename, fromDirectory) {
  var arch = process.arch === 'ia32' ? 'x86' : process.arch;
  var subDir = "node-" + version + "-" + process.platform + "-" + arch;
  var fromPath = path.join(fromDirectory, subDir, 'bin', 'node');
  return mv(fromPath, targetFilename, function(err) {
    if (err) {
      callback(err);
      return;
    }
    fs.chmod(targetFilename, "755", callback);
  });
};

var downloadNode = function(version, done) {
  var arch, downloadURL, filename;
  if (process.platform === 'win32') {
    arch = process.arch === 'x64' ? 'x64/' : '';
    downloadURL = "http://nodejs.org/dist/" + version + "/" + arch + "node.exe";
    filename = path.join('bin', "node.exe");
  } else {
    arch = process.arch === 'ia32' ? 'x86' : process.arch;
    downloadURL = "http://nodejs.org/dist/" + version + "/node-" + version + "-" + process.platform + "-" + arch + ".tar.gz";
    filename = path.join('bin', "node");
  }
  if (fs.existsSync(filename)) {
    done();
    return;
  }
  if (process.platform === 'win32') {
    return downloadFileToLocation(downloadURL, filename, done);
  } else {
    var next = copyNodeBinToLocation.bind(this, done, version, filename);
    return downloadTarballAndExtract(downloadURL, filename, next);
  }
};

downloadNode('v0.10.26', function(error) {
  if (error != null) {
    console.error('Failed to download node', error);
    return process.exit(1);
  } else {
    return process.exit(0);
  }
});
