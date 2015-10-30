'use strict'

const fs = require('fs-plus')
const path = require('path')

module.exports =
class FileSystemBlobStore {
  static load (directory) {
    let instance = new FileSystemBlobStore(directory)
    instance.load()
    return instance
  }

  constructor (directory) {
    this.inMemoryBlobs = new Map()
    this.blobFilename = path.join(directory, 'BLOB')
    this.mapFilename = path.join(directory, 'MAP')
    this.storedBlob = new Buffer(0)
    this.storedMap = {}
  }

  load () {
    if (!fs.existsSync(this.mapFilename)) {
      return
    }
    if (!fs.existsSync(this.blobFilename)) {
      return
    }
    this.storedBlob = fs.readFileSync(this.blobFilename)
    this.storedMap = JSON.parse(fs.readFileSync(this.mapFilename))
  }

  save () {
    let dump = this.getDump()
    let cacheBlob = Buffer.concat(dump[0])
    let cacheMap = JSON.stringify(dump[1])
    fs.writeFileSync(this.blobFilename, cacheBlob)
    fs.writeFileSync(this.mapFilename, cacheMap)
  }

  has (key) {
    return this.inMemoryBlobs.hasOwnProperty(key) || this.storedMap.hasOwnProperty(key)
  }

  get (key) {
    return this.getFromMemory(key) || this.getFromStorage(key)
  }

  set (key, buffer) {
    return this.inMemoryBlobs.set(key, buffer)
  }

  delete (key) {
    this.inMemoryBlobs.delete(key)
    delete this.storedMap[key]
  }

  getFromMemory (key) {
    return this.inMemoryBlobs.get(key)
  }

  getFromStorage (key) {
    if (this.storedMap[key] == null) {
      return
    }

    return this.storedBlob.slice.apply(this.storedBlob, this.storedMap[key])
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

    for (let key of this.inMemoryBlobs.keys()) {
      dump(key, this.getFromMemory.bind(this))
    }

    for (let key of Object.keys(this.storedMap)) {
      if (!cacheMap[key]) {
        dump(key, this.getFromStorage.bind(this))
      }
    }

    return [buffers, cacheMap]
  }
}
