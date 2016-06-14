var fs = require('fs');
var mv = require('mv');
var zlib = require('zlib');
var path = require('path');

var tar = require('tar');
var temp = require('temp');

var request = require('request');

var getInstallNodeVersion = require('./bundled-node-version')

temp.track();

var identifyArch = function() {
  var arch = process.arch === 'ia32' ? 'x86' : process.arch;
  if (arch == 'arm') {
    arch = "armv" + process.config.variables.arm_version + "l";
  }
  return arch;
}

var downloadFileToLocation = function(url, filename, callback) {
  var stream = fs.createWriteStream(filename);
  stream.on('end', callback);
  stream.on('error', callback);
  request.get(url).pipe(stream);
};

var downloadTarballAndExtract = function(url, location, callback) {
  var tempPath = temp.mkdirSync('apm-node-');
  var stream = tar.Extract({
    path: tempPath
  });
  stream.on('end', function() {
    callback.call(this, tempPath);
  });
  stream.on('error', callback);
  var requestStream = request.get(url)
  requestStream.on('response', function(response) {
    if (response.statusCode == 404) {
      console.error('download not found:', url);
      process.exit(1);
    }
    requestStream.pipe(zlib.createGunzip()).pipe(stream);
  });
};

var copyNodeBinToLocation = function(callback, version, targetFilename, fromDirectory) {
  var arch = identifyArch();
  var subDir = "node-" + version + "-" + process.platform + "-" + arch;
  var downloadedNodePath = path.join(fromDirectory, subDir, 'bin', 'node');
  return mv(downloadedNodePath, targetFilename, {mkdirp: true}, function(err) {
    if (err) {
      callback(err);
      return;
    }

    fs.chmodSync(targetFilename, "755");
    callback()
  });
};

var downloadNode = function(version, done) {
  var arch, downloadURL, filename;
  if (process.platform === 'win32') {
    if (process.env.JANKY_SHA1)
      arch = ''; // Always download 32-bit node on Atom Windows CI builds
    else
      arch = process.arch === 'x64' ? 'x64/' : '';
    downloadURL = "http://nodejs.org/dist/" + version + "/win-" + arch + "node.exe";
    filename = path.join('bin', "node.exe");
  } else {
    arch = identifyArch();
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

var versionToInstall = fs.readFileSync(path.resolve(__dirname, '..', 'BUNDLED_NODE_VERSION'), 'utf8').trim()
downloadNode(versionToInstall, function(error) {
  if (error != null) {
    console.error('Failed to download node', error);
    return process.exit(1);
  } else {
    return process.exit(0);
  }
});
