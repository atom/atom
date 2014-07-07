path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'output-long-paths', 'Log long paths in the built application', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')

    longPaths = []
    grunt.file.recurse shellAppDir, (absolutePath, rootPath, relativePath, fileName) ->
      fullPath =  path.join(relativePath, fileName)
      longPaths.push(fullPath) if fullPath.length >= 200

    longPaths.sort (longPath1, longPath2) -> longPath2.length - longPath1.length

    longPaths.forEach (longPath) ->
      grunt.log.error "#{longPath.length} character path: #{longPath}"
