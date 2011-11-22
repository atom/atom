_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'

Extension = require 'resource'
ModalSelector = require 'modal-selector'
Editor = require 'editor'

Base64 = require 'gist/base64'

module.exports =
class Gist extends Editor
  atom.router.add this

  open: (url) ->
    return if not url
    if match = url.match /^https?:\/\/gist\.github\.com\/([^\/]+)\/?/
      super()
      @setCode "Loading Gist..."
      @url = url
      @id = match[1]
      $.ajax
        url: "https://api.github.com/gists/#{@id}"
        error: => @setCode "Loading Gist failed."
        success: (data) =>
          # only one file for now
          @filename = _.first _.keys data.files
          @metadata = _.first _.values data.files
          @setModeForURL @filename
          @setCode @metadata.content
      true

  save: ->
    user = GitHub?.username
    pass = GitHub?.password
   
    if not user or not pass
      console.error "Please set GitHub.username and GitHub.password to save."
      return
    
    # Can't get this to work yet. 500ing
    if @id
      files = {}
      files[@filename] = content: @code()
      $.ajax
        # Needed for CORS, otherwise we send an unparseable Origin
        headers: { origin: null }
        url: "https://api.github.com/gists/#{@id}"
        type: 'patch'
        contentType: 'application/json'
        data: JSON.stringify { files }
        error: -> console.error "Saving Gist failed."
        success: (data) =>
          atom.native.writeToPasteboard @url
          console.log 'it worked'
        beforeSend: (req) =>
          req.setRequestHeader 'Authorization', @authorization user, pass
        true

  # basic auth
  authorization: (user, pass) ->
    token = "#{user}:#{pass}"
    hash = Base64.encode token
    "Basic #{hash}"
