fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->

  grunt.registerTask 'disable-autoupdate', 'Set up disableAutoUpdate field in package.json file', ->
    appDir = fs.realpathSync(grunt.config.get('atom.appDir'))

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))
    metadata._disableAutoUpdate = grunt.config.get('atom.disableAutoUpdate')

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata))
