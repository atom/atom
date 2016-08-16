'use strict'

const fs = require('fs-extra')
const path = require('path')

module.exports = copySync

function copySync(src, dest, opts) {
  const options = Object.assign({filter: () => true}, opts || {})
  const stat = fs.lstatSync(src)
  if (options.filter(src)) {
    if (stat.isFile()) {
      const destDirPath = path.dirname(dest)
      if (!fs.existsSync(destDirPath)) {
        fs.mkdirpSync(destDirPath)
      }
      copyFileSync(src, dest, options)
    } else if (stat.isDirectory()) {
      if (!fs.existsSync(dest)) {
        fs.mkdirpSync(dest)
      }
      fs.readdirSync(src).forEach(content => {
        copySync(path.join(src, content), path.join(dest, content), options)
      })
    } else if (stat.isSymbolicLink()) {
      fs.symlinkSync(fs.readlinkSync(src), dest)
    }
  }
}

const BUF_LENGTH = 4096
const _buff = new Buffer(BUF_LENGTH)

function copyFileSync(srcFile, destFile) {
  if (fs.existsSync(destFile)) {
    fs.chmodSync(destFile, parseInt('777', 8))
    fs.unlinkSync(destFile)
  }

  const fileRead = fs.openSync(srcFile, 'r')
  const stat = fs.fstatSync(fileRead)
  const fileWrite = fs.openSync(destFile, 'w', stat.mode)
  let bytesRead = 1
  let pos = 0

  while (bytesRead > 0) {
    bytesRead = fs.readSync(fileRead, _buff, 0, BUF_LENGTH, pos)
    fs.writeSync(fileWrite, _buff, 0, bytesRead)
    pos += bytesRead
  }

  fs.closeSync(fileRead)
  fs.closeSync(fileWrite)
}
