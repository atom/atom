fs = require 'fs'

# Public:
module.exports =
class HTMLRequire
  @register: ->
    require.extensions['.html'] = (module, filePath) ->
      html = fs.readFileSync(filePath, 'utf8')
      template = document.createElement('template')
      template.innerHTML = html
      docFragment = template.content
      module.exports = new HTMLRequire(template.content)

  constructor: (@documentFragment) ->

  getDocumentFragment: -> @documentFragment

  clone: ->
    @documentFragment.cloneNode(true)
