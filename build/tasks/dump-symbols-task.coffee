async = require 'async'
fs = require 'fs-plus'
path = require 'path'
minidump = require 'minidump'

module.exports = (grunt) ->
  {mkdir, rm} = require('./task-helpers')(grunt)

  dumpSymbolTo = (binaryPath, targetDirectory, callback) ->
    minidump.dumpSymbol binaryPath, (error, content) ->
      return callback(error) if error?

      moduleLine = /MODULE [^ ]+ [^ ]+ ([0-9A-F]+) (.*)\n/.exec(content)
      if moduleLine.length isnt 3
        return callback("Invalid output when dumping symbol for #{binaryPath}")

      filename = moduleLine[2]
      targetPathDirname = path.join(targetDirectory, filename, moduleLine[1])
      mkdir targetPathDirname

      targetPath = path.join(targetPathDirname, "#{filename}.sym")
      fs.writeFile(targetPath, content, callback)

  grunt.registerTask 'dump-symbols', 'Dump symbols for native modules', ->
    done = @async()

    symbolsDir = grunt.config.get('atom.symbolsDir')
    rm symbolsDir
    mkdir symbolsDir

    tasks = []
    onFile = (binaryPath) ->
      if /.*\.node$/.test(binaryPath)
        tasks.push(dumpSymbolTo.bind(this, binaryPath, symbolsDir))
    onDirectory = ->
      true
    fs.traverseTreeSync 'node_modules', onFile, onDirectory

    async.parallel tasks, done
