$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'

# Events:
#   project:load (project) -> Called when a project is loaded.
module.exports =
class Project extends Resource
  window.resourceTypes.push this

  html:
    $ '''
      <div style="position:absolute;bottom:20px;right:20px">
        <img src="https://img.skitch.com/20111112-muhf4t5yh2scut7kwgamaujtyk.png">
      </div>
      '''

  open: (url) ->
    return false if not fs.isDirectory url

    @url = url
    @show()
    atom.trigger 'project:load', this

    true
