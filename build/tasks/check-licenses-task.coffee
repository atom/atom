
module.exports = (grunt) ->
  grunt.registerTask 'check-licenses', 'Report the licenses of all dependencies', ->
    legalEagle = require 'legal-eagle'
    {size, keys} = require 'underscore-plus'
    done = @async()

    options =
      path: process.cwd()
      omitPermissive: true
      overrides: require './license-overrides'

    legalEagle options, (err, summary) ->
      if err?
        console.error(err)
        exit 1

      for key of summary
        delete summary[key] if key.match /^atom@/

      if size(summary)
        console.error "Found dependencies without permissive licenses:"
        for name in keys(summary).sort()
          console.error "#{name}"
          console.error "  License: #{summary[name].license}"
          console.error "  Repository: #{summary[name].repository}"
        process.exit 1
      done()
