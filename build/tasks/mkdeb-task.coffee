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

    {name, version, description} = grunt.file.readJSON('package.json')
    section = 'devel'
    arch = 'amd64'
    maintainer = 'GitHub <support@github.com>'
    data = {name, version, description, section, arch, maintainer}

    control = path.join('resources', 'linux', 'debian', 'control')
    fillTemplate(control, data)
    desktop = path.join('resources', 'linux', 'Atom.desktop')
    fillTemplate(desktop, data)

    cmd = path.join('script', 'mkdeb')
    args = [version, control, desktop, grunt.config.get('atom.buildDir')]
    spawn({cmd, args}, done)
