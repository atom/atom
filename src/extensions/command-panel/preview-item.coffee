{View} = require 'space-pen'

module.exports =
class PreviewItem extends View
  @content: (operation) ->
    @li =>
      @span operation.getPath(), outlet: "path", class: "path"
      @span outlet: "preview", class: "preview", ->
        operation.preview()
