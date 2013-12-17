# Private: TODO remove once telepath upgrades are complete.
module.exports =
class SiteShim
  constructor: (@environment) ->
    {@id} = @environment.state.siteId

  createDocument: (values) ->
    @environment.create(values)
