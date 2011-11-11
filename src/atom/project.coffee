$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Document = require 'document'

module.exports =
class Project extends Document
  @register (path) -> fs.isDirectory path

  html:
    $ '<img src="http://fc01.deviantart.net/fs70/f/2010/184/4/9/Neru_Troll_Face_by_nerutrollfaceplz.jpg">'

  constructor: (@path) ->
    @show()
    super()
