
module.exports = (grunt) ->
  grunt.registerTask 'report-licenses', 'Report the licenses of all dependencies', ->
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
    text += "## #{name}\n\n"
    text += "* License: #{license}\n"
    text += "* License Source: #{source}\n" if source?
    if sourceText?
      text += "* Source Text:\n"
      for line in sourceText.split('\n')
        text += "> #{line}\n"
    text += '\n'
  text
