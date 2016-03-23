var fingerprint = require('../../script/utils/fingerprint')

module.exports = function (grunt) {
  grunt.registerTask('fingerprint', 'Fingerpint the node_modules folder for caching on CI', function () {
    fingerprint.writeFingerprint()
  })
}
