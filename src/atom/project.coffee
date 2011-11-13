$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'

# Events:
#   project:open (project) -> Called when a project is opened.
#   project:resource:open (project, resource) ->
#     Called when the project opens a resource.
#   project:resource:active (project, resource) ->
#     Called when a resource becomes active (i.e. the focal point)
#     in a project.
module.exports =
class Project extends Resource
  window.resourceTypes.push this

  settings:
    ignorePattern: /(\.git|\.xcodeproj|\.DS_Store)/

  resources: {}

  activeResource: null

  responder: ->
    @activeResource or this

  open: (url) ->
    if not @url
      # Can only open directories.
      return false if not fs.isDirectory url

      @url = url
      atom.trigger 'project:open', this

      true
    else if @url
      # Can't open directories once we have a URL.
      if fs.isDirectory url
        return false

      # Ignore non-children files
      if (fs.isFile url) and not @childURL url
        return false

      # Is this resource already open?
      if @resources[url]
        @activeResource = @resources[url]
        atom.trigger 'project:resource:active', this, @activeResource
        @activeResource.show()
        true
      else
        # Try to open all others
        for resourceType in window.resourceTypes
          resource = new resourceType
          break if success = resource.open url

        if success
          @resources[url] = @activeResource = resource
          atom.trigger 'project:resource:open', this, resource
          atom.trigger 'project:resource:active', this, resource
          true

  save: ->
    @activeResource?.save()

  # Determines if a passed URL is a child of @url.
  # Returns a Boolean.
  childURL: (url) ->
    return false if not @url
    parent = @url.replace /([^\/])$/, "$1/"
    child = url.replace /([^\/])$/, "$1/"
    child.match "^" + parent

  urls: (root=@url) ->
    _.reject (fs.list root), (url) => @settings.ignorePattern.test url

  # WARNING THIS IS PROBABLY SLOW
  allURLs: ->
    _.compact _.map (fs.listDirectoryTree @url), (url) =>
      name = url.replace "#{window.url}/", ''
      return if @settings.ignorePattern.test name
      { name, url }
