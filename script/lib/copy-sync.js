'use strict'

const fs = require('fs-extra')
const path = require('path')

module.exports = copySync

function copySync(src, dest, options) {
  options = options || {}
  options.filter = options.filter || () => true

  const destFolder = path.dirname(dest)
  const stat = fs.statSync(src)

  if (options.filter(src)) {
    if (stat.isFile()) {
      if (!fs.existsSync(destFolder)) fs.mkdirsSync(destFolder)
      copyFileSync(src, dest, options)
    } else if (stat.isDirectory()) {
      fs.readdirSync(src).forEach(content => {
        copySync(path.join(src, content), path.join(dest, content), options)
      })
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
