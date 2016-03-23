fs = require 'fs-plus'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  cp: (source, destination, {filter}={}) ->
    unless grunt.file.exists(source)
      grunt.fatal("Cannot copy non-existent #{source.cyan} to #{destination.cyan}")

    copyFile = (sourcePath, destinationPath) ->
      return if filter?(sourcePath) or filter?.test?(sourcePath)

      stats = fs.lstatSync(sourcePath)
      if stats.isSymbolicLink()
        grunt.file.mkdir(path.dirname(destinationPath))
        fs.symlinkSync(fs.readlinkSync(sourcePath), destinationPath)
      else if stats.isFile()
        grunt.file.copy(sourcePath, destinationPath)

      if grunt.file.exists(destinationPath)
        fs.chmodSync(destinationPath, fs.statSync(sourcePath).mode)

    if grunt.file.isFile(source)
      copyFile(source, destination)
    else
      try
        onFile = (sourcePath) ->
          destinationPath = path.join(destination, path.relative(source, sourcePath))
          copyFile(sourcePath, destinationPath)
        onDirectory = (sourcePath) ->
          if fs.isSymbolicLinkSync(sourcePath)
            destinationPath = path.join(destination, path.relative(source, sourcePath))
            copyFile(sourcePath, destinationPath)
            false
          else
            true
        fs.traverseTreeSync source, onFile, onDirectory
      catch error
        grunt.fatal(error)

    grunt.verbose.writeln("Copied #{source.cyan} to #{destination.cyan}.")

  mkdir: (args...) ->
    grunt.file.mkdir(args...)

  rm: (args...) ->
    grunt.file.delete(args..., force: true) if grunt.file.exists(args...)

  spawn: (options, callback) ->
    childProcess = require 'child_process'
    stdout = []
    stderr = []
    error = null
    proc = childProcess.spawn(options.cmd, options.args, options.opts)
    if proc.stdout?
      proc.stdout.on 'data', (data) -> stdout.push(data.toString())
    if proc.stderr?
      proc.stderr.on 'data', (data) -> stderr.push(data.toString())
    proc.on 'error', (processError) -> error ?= processError
    proc.on 'close', (exitCode, signal) ->
      error ?= new Error(signal) if exitCode isnt 0
      results = {stderr: stderr.join(''), stdout: stdout.join(''), code: exitCode}
      grunt.log.error results.stderr if exitCode isnt 0
      callback(error, results, exitCode)

  isAtomPackage: (packagePath) ->
    try
      {engines} = grunt.file.readJSON(path.join(packagePath, 'package.json'))
      engines?.atom?
    catch error
      false

  fillTemplate: (templatePath, outputPath, data) ->
    content = _.template(String(fs.readFileSync(templatePath)))(data)
    grunt.file.write(outputPath, content)
