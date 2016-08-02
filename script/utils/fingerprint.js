var crypto = require('crypto')
var fs = require('fs')
var path = require('path')

var fingerprintPath = path.resolve(__dirname, '..', '..', 'node_modules', '.atom-ci-fingerprint')

module.exports = {
  fingerprint: function () {
    var atomPackageJson = fs.readFileSync(path.resolve(__dirname, '..', '..', 'package.json'))
    var apmPackageJson = fs.readFileSync(path.resolve(__dirname, '..', '..', 'apm', 'package.json'))

    //Include the electron minor version in the fingerprint since that changing requires a re-install
    var electronVersion = JSON.parse(atomPackageJson).electronVersion.replace(/\.\d+$/, '')
    var apmVersion = JSON.parse(apmPackageJson).dependencies['atom-package-manager']

    var body = electronVersion + apmVersion + process.platform + process.version
    return crypto.createHash('sha1').update(body).digest('hex')
  },

  writeFingerprint: function () {
    var fingerprint = this.fingerprint()
    fs.writeFileSync(fingerprintPath, fingerprint)
    console.log('Wrote ci fingerprint:', fingerprintPath, fingerprint)
  },

  readFingerprint: function() {
    if (fs.existsSync(fingerprintPath)) {
      return fs.readFileSync(fingerprintPath).toString()
    } else {
      return null
    }
  },

  fingerprintMatches: function () {
    return this.readFingerprint() && this.readFingerprint() === this.fingerprint()
  }
}
