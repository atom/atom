fs = require 'fs'
path = require 'path'
walkdir = require 'walkdir'

module.exports = (grunt) ->
  cp: (source, destination, {filter}={}) ->
    walkdir.sync source, (sourcePath, stats) ->
      return if filter?.test(sourcePath)

      destinationPath = path.join(destination, path.relative(source, sourcePath))
      if stats.isSymbolicLink()
        grunt.file.mkdir(path.dirname(destinationPath))
        fs.symlinkSync(fs.readlinkSync(sourcePath), destinationPath)
      else if stats.isFile()
        grunt.file.copy(sourcePath, destinationPath)

      if grunt.file.exists(destinationPath)
        fs.chmodSync(destinationPath, fs.statSync(sourcePath).mode)

    grunt.log.writeln("Copied #{source.cyan} to #{destination.cyan}.")

  mkdir: (args...) ->
    grunt.file.mkdir(args...)

  rm: (args...) ->
    grunt.file.delete(args..., force: true) if grunt.file.exists(args...)

  spawn: (options, callback) ->
    grunt.util.spawn options, (error, results, code) ->
      grunt.log.errorlns results.stderr if results.stderr
      callback(error, results, code)
