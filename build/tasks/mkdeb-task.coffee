fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  fillTemplate = (filePath, data) ->
    template = _.template(String(fs.readFileSync("#{filePath}.in")))
    filled = template(data)

    outputPath = path.join(grunt.config.get('atom.buildDir'), path.basename(filePath))
    grunt.file.write(outputPath, filled)
    outputPath

  grunt.registerTask 'mkdeb', 'Create debian package', ->
    done = @async()

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    {name, version, description} = grunt.file.readJSON('package.json')
    section = 'devel'
    maintainer = 'GitHub <atom@github.com>'
    installDir = '/usr'
    iconName = 'atom'
    data = {name, version, description, section, arch, maintainer, installDir, iconName}

    controlFilePath = fillTemplate(path.join('resources', 'linux', 'debian', 'control'), data)
    desktopFilePath = fillTemplate(path.join('resources', 'linux', 'Atom.desktop'), data)
    icon = path.join('resources', 'atom.png')
    buildDir = grunt.config.get('atom.buildDir')

    cmd = path.join('script', 'mkdeb')
    args = [version, arch, controlFilePath, desktopFilePath, icon, buildDir]
    spawn({cmd, args}, done)
