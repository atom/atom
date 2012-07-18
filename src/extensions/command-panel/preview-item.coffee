{View} = require 'space-pen'

module.exports =
class PreviewItem extends View
  @content: (operation) ->
    {prefix, suffix, match} = operation.preview()

    @li =>
      @span operation.getPath(), outlet: "path", class: "path"
      @span outlet: "preview", class: "preview", =>
        @span prefix
        @span match, class: 'match'
        @span suffix


