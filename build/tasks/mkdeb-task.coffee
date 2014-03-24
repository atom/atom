fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'mkdeb', 'Create debian package', ->
    done = @async()
    control = path.join('resources', 'linux', 'debian', 'control')
    controlTemplate = control + '.in'

    {name, version, description} = grunt.file.readJSON('package.json')
    section = 'devel'
    arch = 'amd64'
    maintainer = 'GitHub <support@github.com>'

    template = _.template(String(fs.readFileSync(controlTemplate)))
    filled = template({name, version, description, section, arch, maintainer})
    fs.writeFileSync(control, filled)

    cmd = path.join('script', 'mkdeb')
    args = [version, control, grunt.config.get('atom.buildDir')]
    spawn({cmd, args}, done)
