var Path = require('path');
var fs = require('fs-plus');

module.exports = FileSystemCacheStorage = (function() {
  function FileSystemCacheStorage(directory) {
    this.directory = directory;
    this.cachedPathsByKey = {};
  }

  FileSystemCacheStorage.prototype.has = function(key) {
    return fs.existsSync(this.pathForKey(key));
  };

  FileSystemCacheStorage.prototype.get = function(key) {
    return fs.readFileSync(this.pathForKey(key));
  };

  FileSystemCacheStorage.prototype.set = function(key, value) {
    fs.writeFileSync(this.pathForKey(key), value);
  };

  FileSystemCacheStorage.prototype.pathForKey = function(key) {
    var path = this.cachedPathsByKey[key];
    if (!path) {
      path = key.replace(/[\/.]/g, '-');
      this.cachedPathsByKey[key] = path;
    }

    return Path.join(this.directory, path);
  };

  return FileSystemCacheStorage;
})();
