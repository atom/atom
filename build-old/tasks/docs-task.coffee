path = require 'path'

fs = require 'fs-plus'
_ = require 'underscore-plus'

donna = require 'donna'
joanna = require 'joanna'
tello = require 'tello'
glob = require 'glob'

module.exports = (grunt) ->
  getClassesToInclude = ->
    modulesPath = path.resolve(__dirname, '..', '..', 'node_modules')
    classes = {}
    fs.traverseTreeSync modulesPath, (modulePath) ->
      return false if modulePath.match(/node_modules/g).length > 1 # dont need the dependencies of the dependencies
      return true unless path.basename(modulePath) is 'package.json'
      return true unless fs.isFileSync(modulePath)

      apiPath = path.join(path.dirname(modulePath), 'api.json')
      if fs.isFileSync(apiPath)
        _.extend(classes, grunt.file.readJSON(apiPath).classes)
      true
    classes

  sortClasses = (classes) ->
    sortedClasses = {}
    for className in Object.keys(classes).sort()
      sortedClasses[className] = classes[className]
    sortedClasses

  grunt.registerTask 'build-docs', 'Builds the API docs in src', ->
    docsOutputDir = grunt.config.get('docsOutputDir')

    [coffeeMetadata] = donna.generateMetadata(['.'])
    jsMetadata = joanna(glob.sync('src/*.js'))

    metadata = {
      repository: coffeeMetadata.repository,
      version: coffeeMetadata.version,
      files: Object.assign(coffeeMetadata.files, jsMetadata.files)
    }

    api = tello.digest([metadata])
    _.extend(api.classes, getClassesToInclude())
    api.classes = sortClasses(api.classes)

    apiJson = JSON.stringify(api, null, 2)
    apiJsonPath = path.join(docsOutputDir, 'api.json')
    grunt.file.write(apiJsonPath, apiJson)
