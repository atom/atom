fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

fillTemplate = (filePath, data) ->
  template = _.template(String(fs.readFileSync(filePath + '.in')))
  filled = template(data)
  fs.writeFileSync(filePath, filled)

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

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
    data = {name, version, description, section, arch, maintainer}

    control = path.join('resources', 'linux', 'debian', 'control')
    fillTemplate(control, data)
    desktop = path.join('resources', 'linux', 'Atom.desktop')
    fillTemplate(desktop, data)
    icon = path.join('resources', 'atom.png')
    buildDir = grunt.config.get('atom.buildDir')

    cmd = path.join('script', 'mkdeb')
    args = [version, arch, control, desktop, icon, buildDir]
    spawn({cmd, args}, done)
