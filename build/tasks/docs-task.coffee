path = require 'path'

fs = require 'fs-plus'
_ = require 'underscore-plus'

donna = require 'donna'
tello = require 'tello'

module.exports = (grunt) ->
  getClassesToInclude = ->
    modulesPath = path.resolve(__dirname, '..', '..', 'node_modules')
    classes = {}
    fs.traverseTreeSync modulesPath, (modulePath) ->
      return true unless path.basename(modulePath) is 'package.json'
      return true unless fs.isFileSync(modulePath)

      apiPath = path.join(path.dirname(modulePath), 'api.json')
      if fs.isFileSync(apiPath)
        _.extend(classes, grunt.file.readJSON(apiPath).classes)
      true
    classes

  grunt.registerTask 'build-docs', 'Builds the API docs in src', ->
    docsOutputDir = grunt.config.get('docsOutputDir')

    metadata = donna.generateMetadata(['.'])
    api = _.extend(tello.digest(metadata), getClassesToInclude())
    apiJson = JSON.stringify(api, null, 2)
    apiJsonPath = path.join(docsOutputDir, 'api.json')
    grunt.file.write(apiJsonPath, apiJson)
