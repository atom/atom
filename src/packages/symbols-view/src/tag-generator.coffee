Point = require 'point'
ChildProcess = require 'child-process'

module.exports =
class TagGenerator

  constructor: (@path, @callback) ->

  parseTagLine: (line) ->
    sections = line.split('\t')
    if sections.length > 3
      position: new Point(parseInt(sections[2]) - 1)
      name: sections[0]
    else
      null

  generate: ->
    options =
      bufferLines: true
      stdout: (data) =>
        lines = data.split('\n')
        for line in lines
          tag = @parseTagLine(line)
          @callback(tag) if tag
    command = "#{require.resolve('ctags')} --fields=+KS -nf - #{@path}"
    ChildProcess.exec(command, options)
