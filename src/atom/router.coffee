module.exports =
class Router
  resources: []

  add: (resource) ->
    @resources.unshift resource

  open: (url) ->
    success = false

    for resourceType in @resources
      resource = new resourceType
      break if success = resource.open url

    resource if success
