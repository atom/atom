$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'

module.exports =
class Project extends Resource
  window.resourceTypes.push this

  html:
    $ '<img src="http://fc01.deviantart.net/fs70/f/2010/184/4/9/Neru_Troll_Face_by_nerutrollfaceplz.jpg">'

  open: (url) ->
    return false if not fs.isDirectory url

    @url = url
    @show()
