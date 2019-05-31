'use strict';

const fs = require('fs-plus');
const path = require('path');

module.exports = class FileSystemBlobStore {
  static load(directory) {
    let instance = new FileSystemBlobStore(directory);
    instance.load();
    return instance;
  }

  constructor(directory) {
    this.blobFilename = path.join(directory, 'BLOB');
    this.blobMapFilename = path.join(directory, 'MAP');
    this.lockFilename = path.join(directory, 'LOCK');
    this.reset();
  }

  reset() {
    this.inMemoryBlobs = new Map();
    this.storedBlob = Buffer.alloc(0);
    this.storedBlobMap = {};
    this.usedKeys = new Set();
  }

  load() {
    if (!fs.existsSync(this.blobMapFilename)) {
      return;
    }
    if (!fs.existsSync(this.blobFilename)) {
      return;
    }

    try {
      this.storedBlob = fs.readFileSync(this.blobFilename);
      this.storedBlobMap = JSON.parse(fs.readFileSync(this.blobMapFilename));
    } catch (e) {
      this.reset();
    }
  }

  save() {
    let dump = this.getDump();
    let blobToStore = Buffer.concat(dump[0]);
    let mapToStore = JSON.stringify(dump[1]);

    let acquiredLock = false;
    try {
      fs.writeFileSync(this.lockFilename, 'LOCK', { flag: 'wx' });
      acquiredLock = true;

      fs.writeFileSync(this.blobFilename, blobToStore);
      fs.writeFileSync(this.blobMapFilename, mapToStore);
    } catch (error) {
      // Swallow the exception silently only if we fail to acquire the lock.
      if (error.code !== 'EEXIST') {
        throw error;
      }
    } finally {
      if (acquiredLock) {
        fs.unlinkSync(this.lockFilename);
      }
    }
  }

  has(key) {
    return (
      this.inMemoryBlobs.has(key) || this.storedBlobMap.hasOwnProperty(key)
    );
  }

  get(key) {
    if (this.has(key)) {
      this.usedKeys.add(key);
      return this.getFromMemory(key) || this.getFromStorage(key);
    }
  }

  set(key, buffer) {
    this.usedKeys.add(key);
    return this.inMemoryBlobs.set(key, buffer);
  }

  delete(key) {
    this.inMemoryBlobs.delete(key);
    delete this.storedBlobMap[key];
  }

  getFromMemory(key) {
    return this.inMemoryBlobs.get(key);
  }

  getFromStorage(key) {
    if (!this.storedBlobMap[key]) {
      return;
    }

    return this.storedBlob.slice.apply(
      this.storedBlob,
      this.storedBlobMap[key]
    );
  }

  getDump() {
    let buffers = [];
    let blobMap = {};
    let currentBufferStart = 0;

    function dump(key, getBufferByKey) {
      let buffer = getBufferByKey(key);
      buffers.push(buffer);
      blobMap[key] = [currentBufferStart, currentBufferStart + buffer.length];
      currentBufferStart += buffer.length;
    }

    for (let key of this.inMemoryBlobs.keys()) {
      if (this.usedKeys.has(key)) {
        dump(key, this.getFromMemory.bind(this));
      }
    }

    for (let key of Object.keys(this.storedBlobMap)) {
      if (!blobMap[key] && this.usedKeys.has(key)) {
        dump(key, this.getFromStorage.bind(this));
      }
    }

    return [buffers, blobMap];
  }
};
