$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'

# Events:
#   project:open (project) -> Called when a project is opened.
#   project:resource:open (project, resource) ->
#     Called when the project opens a resource.
#   project:resource:close (project, resource) ->
#     Called when the project closes a resource.
#   project:resource:active (project, resource) ->
#     Called when a resource becomes active (i.e. the focal point)
#     in a project.
module.exports =
class Project extends Resource
  window.resourceTypes.push this

  settings:
    # Regexp used to ignore paths.
    ignorePattern: /(\.git|\.xcodeproj|\.DS_Store|node_modules|\.bundle|\.sass-cache|vendor)/

    # Arrays of { name, url, type } keyed by the root URL.
    # Used when looking up a directory's contents by url
    # to add metadata such as magic files or directories.
    extraURLs: {}

  resources: {}

  responder: ->
    @activeResource() or this

  open: (url) ->
    if not @url
      # Can only open directories.
      return false if not fs.isDirectory url

      @url = url
      window.setTitle @title()
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
      if resource = @resources[url]
        @setActiveResource resource
        resource.show()
        true
      else
        # Try to open all others
        for resourceType in window.resourceTypes
          resource = new resourceType
          break if success = resource.open url

        if success
          @resources[url] = resource
          atom.trigger 'project:resource:open', this, resource
          @setActiveResource resource
          true

  close: (url) ->
    if url
      resource = @resources[url]
    else
      resource = @activeResource()

    if resource
      return true if resource?.close()

      delete @resources[resource.url]
      @setActiveResource()
      atom.trigger 'project:resource:close', this, resource
      @activeResource()?.show()

      true

  save: ->
    @activeResource()?.save()

  # Finds the active resource or makes a guess based on open resources.
  # Returns a resource or null.
  activeResource: ->
    @__activeResource or @setActiveResource()

  # Sets a resource as active.
  #
  # resource - Optional. The resource to set as active.
  #            If none given tries to pick one.
  #
  # Returns the resource that was set to active if we succeeded.
  # Returns null if we couldn't set any resource to active.
  setActiveResource: (resource) ->
    if not resource
      resource = _.last _.values @resources

    @__activeResource = resource

    if resource
      atom.trigger 'project:resource:active', this, resource
      resource

  title: ->
    _.last @url.split '/'

  # Determines if a passed URL is a child of @url.
  # Returns a Boolean.
  childURL: (url) ->
    return false if not @url
    parent = @url.replace /([^\/])$/, "$1/"
    child = url.replace /([^\/])$/, "$1/"
    child.match "^" + parent

  urls: (root=@url) ->
    _.compact _.map (fs.list root), (url) =>
      return if @settings.ignorePattern.test url
      type: if fs.isDirectory url then 'dir' else 'file'
      name: url.replace(root, "").substring 1
      url: url
    .concat @settings.extraURLs[root] or []

  # WARNING THIS IS PROBABLY SLOW
  allURLs: ->
    _.compact _.map (fs.listDirectoryTree @url), (url) =>
      name = url.replace "#{window.url}/", ''
      return if @settings.ignorePattern.test name
      { name, url }
