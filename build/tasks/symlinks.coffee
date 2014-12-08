fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'symlinks', 'create docapp project', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    configDir = grunt.option 'portable'
    projectDir = grunt.option 'project'
    if shellAppDir and configDir and projectDir
      fs.symlinkSync configDir, path.join(shellAppDir, '.atom'), 'dir'
      fs.symlinkSync projectDir, path.join(shellAppDir, 'project'), 'dir'

