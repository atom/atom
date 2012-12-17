Point = require 'point'
ChildProcess = require 'child-process'

module.exports =
class TagGenerator

  constructor: (@path, @callback) ->

  parsePrefix: (section = "") ->
    if section.indexOf('class:') is 0
      section.substring(6)
    else if section.indexOf('namespace:') is 0
      section.substring(10)
    else if section.indexOf('file:') is 0
      section.substring(5)
    else if section.indexOf('signature:') is 0
      section.substring(10)
    else if section.indexOf('struct:') is 0
      section.substring(7)
    else
      section

  parseTagLine: (line) ->
    sections = line.split('\t')
    return null if sections.length < 4

    label = sections[0]
    line = parseInt(sections[2]) - 1
    if sections.length > 5
      if prefix = @parsePrefix(sections[4])
        label = "#{prefix}::#{label}"
      if suffix = @parsePrefix(sections[5])
        label = "#{label}#{suffix}"
    else
      if suffix = @parsePrefix(sections[4])
        label = "#{label}#{suffix}"

    tag =
      position: new Point(line, 0)
      name: label

    return tag

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
