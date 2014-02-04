path = require 'path'
url = require 'url'
request = require 'request'
fs = require './fs'
TextMateTheme = require './text-mate-theme'

# Convert a TextMate theme to an Atom theme
module.exports =
class ThemeConverter
  constructor: (@sourcePath, destinationPath) ->
    @destinationPath = path.resolve(destinationPath)

  readTheme: (callback) ->
    {protocol} = url.parse(@sourcePath)
    if protocol is 'http:' or protocol is 'https:'
      request @sourcePath, (error, response, body) =>
        if error?
          callback(error)
        else  if response.statusCode isnt 200
          callback("Request to #{@sourcePath} failed (#{response.statusCode})")
        else
          callback(null, body)
    else
      sourcePath = path.resolve(@sourcePath)
      if fs.isFileSync(sourcePath)
        callback(null, fs.readFileSync(sourcePath, 'utf8'))
      else
        callback("TextMate theme file not found: #{sourcePath}")

  convert: (callback) ->
    @readTheme (error, themeContents) =>
      return callback(error) if error?

      TextMateTheme = require './text-mate-Theme'
      theme = new TextMateTheme(themeContents)
      fs.writeFileSync(path.join(@destinationPath, 'index.less'), theme.getStylesheet())
      callback()
