# Private: TODO remove once telepath upgrades are complete.
module.exports =
class SiteShim
  constructor: (document) ->
    @setRootDocument(document)

  setRootDocument: (@document) ->
    @id = @document.siteId

  createDocument: (values) ->
    @document.create({values})
