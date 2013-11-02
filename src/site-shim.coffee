module.exports =
class SiteShim
  constructor: (document) ->
    @setRootDocument(document)

  setRootDocument: (@document) ->
    @id = @document.siteId
    @document.set('looseDocuments', [])

  createDocument: (values) ->
    @document.get('looseDocuments').push(values)
