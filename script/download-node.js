#!/usr/bin/env node
var fs = require('fs');
var mv = require('mv');
var zlib = require('zlib');
var path = require('path');

// Use whichever version of the local request helper is available
// This might be the JavaScript or CoffeeScript version depending
// on whether this module is being installed explictly or
// `npm install` is being run at the root of the repository.
var request = null;
try {
  request = require('../lib/request');
} catch (error) {
  require('coffee-script').register();
  request = require('../src/request');
}

var tar = require('npm/node_modules/tar');
var temp = require('temp');

temp.track();

var downloadFileToLocation = function(url, filename, callback) {
  var stream = fs.createWriteStream(filename);
  stream.on('end', callback);
  stream.on('error', callback);
  request.createReadStream({url: url}, function(requestStream) {
    requestStream.pipe(stream);
  });
};

var downloadTarballAndExtract = function(url, location, callback) {
  var tempPath = temp.mkdirSync('apm-node-');
  var stream = tar.Extract({
    path: tempPath
  });
  stream.on('end', callback.bind(this, tempPath));
  stream.on('error', callback);
  request.createReadStream({url: url}, function(requestStream) {
    requestStream.pipe(zlib.createGunzip()).pipe(stream);
  });
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

var getInstallNodeVersion = function(filename, callback) {
  require('child_process').exec(filename + ' -v', function(error, stdout) {
    var version = null;
    if (stdout != null) {
      version = stdout.toString().trim();
    }
    callback(error, version);
  });
}

var downloadNode = function(version, done) {
  var arch, downloadURL, filename;
  if (process.platform === 'win32') {
    if (process.env.JANKY_SHA1)
      arch = ''; // Always download 32-bit node on Atom Windows CI builds
    else
      arch = process.arch === 'x64' ? 'x64/' : '';
    downloadURL = "http://nodejs.org/dist/" + version + "/" + arch + "node.exe";
    filename = path.join('bin', "node.exe");
  } else {
    arch = process.arch === 'ia32' ? 'x86' : process.arch;
    downloadURL = "http://nodejs.org/dist/" + version + "/node-" + version + "-" + process.platform + "-" + arch + ".tar.gz";
    filename = path.join('bin', "node");
  }

  var downloadFile = function() {
    if (process.platform === 'win32') {
      downloadFileToLocation(downloadURL, filename, done);
    } else {
      var next = copyNodeBinToLocation.bind(this, done, version, filename);
      downloadTarballAndExtract(downloadURL, filename, next);
    }
  };

  if (fs.existsSync(filename)) {
    getInstallNodeVersion(filename, function(error, installedVersion) {
      if(error != null) {
        done(error);
      } else if (installedVersion !== version) {
        downloadFile();
      } else {
        done();
      }
    });
  } else {
    downloadFile();
  }
};

downloadNode('v0.10.35', function(error) {
  if (error != null) {
    console.error('Failed to download node', error);
    return process.exit(1);
  } else {
    return process.exit(0);
  }
});
