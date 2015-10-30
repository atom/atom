(function() {
  var FileSystemCacheBlobStorage;
  var fs = require('fs-plus');
  var path = require('path');

  module.exports = FileSystemCacheBlobStorage = (function() {
    FileSystemCacheBlobStorage.load = function(directory) {
      var instance = new FileSystemCacheBlobStorage(directory);
      instance.load();
      return instance;
    };

    function FileSystemCacheBlobStorage(directory) {
      this.inMemoryCache = new Map;
      this.cacheBlobFilename = path.join(directory, "v8-compile-cache.blob");
      this.cacheMapFilename = path.join(directory, "v8-compile-cache.map");
      this.storedCacheBlob = new Buffer(0);
      this.storedCacheMap = {};
    }

    FileSystemCacheBlobStorage.prototype.load = function() {
      if (!fs.existsSync(this.cacheMapFilename)) {
        return;
      }
      if (!fs.existsSync(this.cacheBlobFilename)) {
        return;
      }
      this.storedCacheBlob = fs.readFileSync(this.cacheBlobFilename);
      this.storedCacheMap = JSON.parse(fs.readFileSync(this.cacheMapFilename));
    };

    FileSystemCacheBlobStorage.prototype.save = function() {
      var dump = this.getDump();
      var buffers = dump[0];
      var cacheMap = dump[1];
      cacheMap = JSON.stringify(cacheMap);
      cacheBlob = Buffer.concat(buffers);
      fs.writeFileSync(this.cacheBlobFilename, cacheBlob);
      fs.writeFileSync(this.cacheMapFilename, cacheMap);
    };

    FileSystemCacheBlobStorage.prototype.has = function(key) {
      return this.inMemoryCache.hasOwnProperty(key) || this.storedCacheMap.hasOwnProperty(key);
    };

    FileSystemCacheBlobStorage.prototype.get = function(key) {
      return this.getFromMemory(key) || this.getFromStorage(key);
    };

    FileSystemCacheBlobStorage.prototype.set = function(key, buffer) {
      return this.inMemoryCache.set(key, buffer);
    };

    FileSystemCacheBlobStorage.prototype.getFromMemory = function(key) {
      return this.inMemoryCache.get(key);
    };

    FileSystemCacheBlobStorage.prototype.getFromStorage = function(key) {
      if (this.storedCacheMap[key] == null) {
        return;
      }

      return this.storedCacheBlob.slice.apply(this.storedCacheBlob, this.storedCacheMap[key]);
    };

    FileSystemCacheBlobStorage.prototype.getDump = function() {
      var self = this;
      var buffers = [];
      var cacheMap = {};
      var currentBufferStart = 0;
      function dump(key, getBufferByKey) {
        var buffer = getBufferByKey.bind(self)(key);
        buffers.push(buffer);
        cacheMap[key] = [currentBufferStart, currentBufferStart + buffer.length];
        currentBufferStart += buffer.length;
      };

      this.inMemoryCache.forEach(function(__, key) {
        dump(key, self.getFromMemory);
      });
      Object.keys(this.storedCacheMap).forEach(function(key) {
        if (!cacheMap[key]) {
          dump(key, self.getFromStorage);
        }
      });

      return [buffers, cacheMap];
    };

    return FileSystemCacheBlobStorage;

  })();

}).call(this);
