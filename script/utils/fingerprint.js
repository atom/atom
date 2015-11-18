var crypto = require('crypto')
var fs = require('fs')
var path = require('path')

var fingerprintPath = path.resolve(__dirname, '..', '..', 'node_modules', '.atom-ci-fingerprint')

module.exports = {
  fingerprint: function () {
    var packageJson = fs.readFileSync(path.resolve(__dirname, '..', '..', 'package.json'))
    var body = packageJson.toString() + process.platform + process.version
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
