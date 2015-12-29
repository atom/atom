fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'output-module-counts', 'Log modules where more than one copy exists in node_modules', ->
    nodeModulesDir = path.resolve(__dirname, '..', '..', 'node_modules')

    otherModules = {}
    atomModules = {}

    sortModuleNames = (modules) ->
      Object.keys(modules).sort (name1, name2) ->
        diff = modules[name2].count - modules[name1].count
        diff = name1.localeCompare(name2) if diff is 0
        diff

    getAtomTotal = ->
      Object.keys(atomModules).length

    getOtherTotal = ->
      Object.keys(otherModules).length

    recurseHandler = (absolutePath, rootPath, relativePath, fileName) ->
      return if fileName isnt 'package.json'

      {name, version, repository} = grunt.file.readJSON(absolutePath)
      return unless name and version

      repository = repository.url if repository?.url

      if /.+\/atom\/.+/.test(repository)
        modules = atomModules
      else
        modules = otherModules

      modules[name] ?= {versions: {}, count: 0}
      modules[name].count++
      modules[name].versions[version] = true

    walkNodeModuleDir = ->
      grunt.file.recurse(nodeModulesDir, recurseHandler)

    # Handle broken symlinks that grunt.file.recurse fails to handle
    loop
      try
        walkNodeModuleDir()
        break
      catch error
        if error.code is 'ENOENT'
          fs.unlinkSync(error.path)
          otherModules = {}
          atomModules = {}
        else
          break

    if getAtomTotal() > 0
      console.log "Atom Modules: #{getAtomTotal()}"
      sortModuleNames(atomModules).forEach (name) ->
        {count, versions, atom} = atomModules[name]
        grunt.log.error "#{name}: #{count} (#{Object.keys(versions).join(', ')})" if count > 1
      console.log()

    console.log "Other Modules: #{getOtherTotal()}"
    sortModuleNames(otherModules).forEach (name) ->
      {count, versions, atom} = otherModules[name]
      grunt.log.error "#{name}: #{count} (#{Object.keys(versions).join(', ')})" if count > 1
