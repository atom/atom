path = require 'path'

module.exports = (grunt) ->
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'copy-info-plist', 'Copy plist', ->
    contentsDir = grunt.config.get('atom.contentsDir')
    plistPath = path.join(contentsDir, 'Info.plist')
    helperPlistPath = path.join(contentsDir, 'Frameworks/Scroll Helper.app/Contents/Info.plist')

    # Copy custom plist files
    cp 'resources/mac/atom-Info.plist', plistPath
    cp 'resources/mac/helper-Info.plist',  helperPlistPath
