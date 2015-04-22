fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn, rm, mkdir} = require('./task-helpers')(grunt)

  fillTemplate = (filePath, data) ->
    template = _.template(String(fs.readFileSync("#{filePath}.in")))
    filled = template(data)

    outputPath = path.join(grunt.config.get('atom.buildDir'), path.basename(filePath))
    grunt.file.write(outputPath, filled)
    outputPath

  grunt.registerTask 'mkrpm', 'Create rpm package', ->
    done = @async()

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    {name, version, description} = grunt.file.readJSON('package.json')
    buildDir = grunt.config.get('atom.buildDir')

    rpmDir = path.join(buildDir, 'rpm')
    rm rpmDir
    mkdir rpmDir

    installDir = grunt.config.get('atom.installDir')
    shareDir = path.join(installDir, 'share', 'atom')
    iconName = 'atom'
    executable = path.join(shareDir, 'atom')

    data = {name, version, description, installDir, iconName, executable}
    specFilePath = fillTemplate(path.join('resources', 'linux', 'redhat', 'atom.spec'), data)
    desktopFilePath = fillTemplate(path.join('resources', 'linux', 'atom.desktop'), data)

    cmd = path.join('script', 'mkrpm')
    args = [specFilePath, desktopFilePath, buildDir]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created rpm package in #{rpmDir}"
        done()
