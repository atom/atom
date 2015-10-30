'use strict'

const fs = require('fs-plus')
const path = require('path')

module.exports =
class FileSystemCacheBlobStorage {
  static load (directory) {
    let instance = new FileSystemCacheBlobStorage(directory)
    instance.load()
    return instance
  }

  constructor (directory) {
    this.inMemoryCache = new Map()
    this.cacheBlobFilename = path.join(directory, 'v8-compile-cache.blob')
    this.cacheMapFilename = path.join(directory, 'v8-compile-cache.map')
    this.storedCacheBlob = new Buffer(0)
    this.storedCacheMap = {}
  }

  load () {
    if (!fs.existsSync(this.cacheMapFilename)) {
      return
    }
    if (!fs.existsSync(this.cacheBlobFilename)) {
      return
    }
    this.storedCacheBlob = fs.readFileSync(this.cacheBlobFilename)
    this.storedCacheMap = JSON.parse(fs.readFileSync(this.cacheMapFilename))
  }

  save () {
    let dump = this.getDump()
    let cacheBlob = Buffer.concat(dump[0])
    let cacheMap = JSON.stringify(dump[1])
    fs.writeFileSync(this.cacheBlobFilename, cacheBlob)
    fs.writeFileSync(this.cacheMapFilename, cacheMap)
  }

  has (key) {
    return this.inMemoryCache.hasOwnProperty(key) || this.storedCacheMap.hasOwnProperty(key)
  }

  get (key) {
    return this.getFromMemory(key) || this.getFromStorage(key)
  }

  set (key, buffer) {
    return this.inMemoryCache.set(key, buffer)
  }

  delete (key) {
    this.inMemoryCache.delete(key)
    delete this.storedCacheMap[key]
  }

  getFromMemory (key) {
    return this.inMemoryCache.get(key)
  }

  getFromStorage (key) {
    if (this.storedCacheMap[key] == null) {
      return
    }

    return this.storedCacheBlob.slice.apply(this.storedCacheBlob, this.storedCacheMap[key])
  }

  getDump () {
    let buffers = []
    let cacheMap = {}
    let currentBufferStart = 0

    function dump (key, getBufferByKey) {
      let buffer = getBufferByKey(key)
      buffers.push(buffer)
      cacheMap[key] = [currentBufferStart, currentBufferStart + buffer.length]
      currentBufferStart += buffer.length
    }

    for (let key of this.inMemoryCache.keys()) {
      dump(key, this.getFromMemory.bind(this))
    }

    for (let key of Object.keys(this.storedCacheMap)) {
      if (!cacheMap[key]) {
        dump(key, this.getFromStorage.bind(this))
      }
    }

    return [buffers, cacheMap]
  }
}
