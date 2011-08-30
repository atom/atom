$ = require 'jquery'
_ = require 'underscore'

{Chrome, Dir, File} = require 'osx'

_.map Dir.list(Chrome.appRoot() + "/plugins"), (plugin) ->
  require plugin

if css = File.read "~/.atomicity/twilight.css"
  head = $('head')[0]
  style = document.createElement 'style'
  rules = document.createTextNode css
  style.type = 'text/css'
  style.appendChild rules
  head.appendChild style

_.map Dir.list("~/.atomicity/"), (path) ->
  require path
