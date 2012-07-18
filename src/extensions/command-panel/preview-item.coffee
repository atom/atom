{View} = require 'space-pen'

module.exports =
class PreviewItem extends View
  @content: (operation) ->
    @li =>
      @span operation.getPath()
      @span operation.preview()
