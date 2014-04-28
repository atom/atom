(function() {
  var copyNodeBinToLocation, downloadFileToLocation, downloadNode, downloadTarballAndExtract, fs, path, request, tar, temp, zlib;

  fs = require('fs');

  zlib = require('zlib');

  path = require('path');

  request = require('request');

  tar = require('tar');

  temp = require('temp');

  temp.track();

  downloadFileToLocation = function(url, filename, callback) {
    var stream;
    stream = fs.createWriteStream(filename);
    stream.on('end', callback);
    stream.on('error', callback);
    return request(url).pipe(stream);
  };

  downloadTarballAndExtract = function(url, location, callback) {
    var stream, tempPath;
    tempPath = temp.mkdirSync('apm-node-');
    stream = tar.Extract({
      path: tempPath
    });
    stream.on('end', callback.bind(this, tempPath));
    stream.on('error', callback);
    return request(url).pipe(zlib.createGunzip()).pipe(stream);
  };

  copyNodeBinToLocation = function(callback, version, targetFilename, fromDirectory) {
    var arch, fromPath, subDir;
    arch = process.arch === 'ia32' ? 'x86' : process.arch;
    subDir = "node-" + version + "-" + process.platform + "-" + arch;
    fromPath = path.join(fromDirectory, subDir, 'bin', 'node');
    return fs.rename(fromPath, targetFilename, callback);
  };

  downloadNode = function(version, done) {
    var arch, downloadURL, filename, next;
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
      next = copyNodeBinToLocation.bind(this, done, version, filename);
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

}).call(this);
