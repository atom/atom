path = require 'path'
url = require 'url'
fs = require './fs'
request = require './request'
TextMateTheme = require './text-mate-theme'

# Convert a TextMate theme to an Atom theme
module.exports =
class ThemeConverter
  constructor: (@sourcePath, destinationPath) ->
    @destinationPath = path.resolve(destinationPath)

  readTheme: (callback) ->
    {protocol} = url.parse(@sourcePath)
    if protocol is 'http:' or protocol is 'https:'
      requestOptions = url: @sourcePath
      request.get requestOptions, (error, response, body) =>
        if error?
          if error.code is 'ENOTFOUND'
            error = "Could not resolve URL: #{@sourcePath}"
          callback(error)
        else  if response.statusCode isnt 200
          callback("Request to #{@sourcePath} failed (#{response.headers.status})")
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

      try
        theme = new TextMateTheme(themeContents)
      catch error
        return callback(error)

      fs.writeFileSync(path.join(@destinationPath, 'styles', 'base.less'), theme.getStylesheet())
      fs.writeFileSync(path.join(@destinationPath, 'styles', 'syntax-variables.less'), theme.getSyntaxVariables())
      callback()
