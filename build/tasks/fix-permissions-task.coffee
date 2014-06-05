fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->

  grunt.registerTask 'fix-permissions', 'Fix permissions on binary generated in build directory', (mode) ->
      fs.chmodSync(path.join(grunt.config.get('atom.contentsDir'), 'atom'), mode)
