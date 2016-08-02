const crypto = require('crypto')
const fs = require('fs')
const path = require('path')

const CONFIG = require('../config')
const FINGERPRINT_PATH = path.join(CONFIG.repositoryRootPath, 'node_modules', '.atom-ci-fingerprint')

exports.writeFingerprint = function () {
  const fingerprint = computeFingerprint()
  fs.writeFileSync(FINGERPRINT_PATH, fingerprint)
  console.log('Wrote CI fingerprint:', FINGERPRINT_PATH, fingerprint)
},

exports.fingerprintMatches = function () {
  const oldFingerprint = readFingerprint()
  return oldFingerprint && oldFingerprint === computeFingerprint()
}

function computeFingerprint () {
  //Include the electron minor version in the fingerprint since that changing requires a re-install
  const electronVersion = CONFIG.appMetadata.electronVersion.replace(/\.\d+$/, '')
  const apmVersion = CONFIG.apmMetadata.version

  const body = electronVersion + apmVersion + process.platform + process.version
  return crypto.createHash('sha1').update(body).digest('hex')
}

function readFingerprint () {
  if (fs.existsSync(FINGERPRINT_PATH)) {
    return fs.readFileSync(FINGERPRINT_PATH, 'utf8')
  } else {
    return null
  }
}
