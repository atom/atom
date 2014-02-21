
module.exports = (grunt) ->
  grunt.registerTask 'generate-license', 'Generate the license, including the licenses of all dependencies', ->
    legalEagle = require 'legal-eagle'
    done = @async()

    options =
      path: process.cwd()
      overrides: require './license-overrides'

    legalEagle options, (err, summary) ->
      if err?
        console.error(err)
        exit 1
      console.log getSummaryText(summary)
      done()

getSummaryText = (summary) ->
  {keys} = require 'underscore-plus'
  text = ""
  names = keys(summary).sort()
  for name in names
    {license, source, sourceText} = summary[name]

    text += "-------------------------------------------------------------------------\n\n"
    text += "Package: #{name}\n"
    text += "License: #{license}\n"
    text += "License Source: #{source}\n" if source?
    if sourceText?
      text += "Source Text:\n\n"
      text += sourceText
    text += '\n'
  text
