$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Document = require 'document'

module.exports =
class Project extends Document
  window.resourceTypes.push this

  html:
    $ '<img src="http://fc01.deviantart.net/fs70/f/2010/184/4/9/Neru_Troll_Face_by_nerutrollfaceplz.jpg">'

  open: (path) ->
    return false if not fs.isDirectory url

    #if not @path

    #parent = @path.replace(/([^\/])$/, "$1/")
    #child = path.replace(/([^\/])$/, "$1/")

    # If the child is contained by the parent, it can be opened by this window
    #child.match "^" + parent

    @path = path
    @show()
