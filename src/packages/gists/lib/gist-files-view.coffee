{$$} = require 'space-pen'
SelectList = require 'select-list'
humanize = require 'humanize-plus'
_ = require 'underscore'
{openGistFile} = require './gist-utils'

module.exports =
class GistFilesView extends SelectList
  @viewClass: -> "#{super} gists-files-view overlay from-top"

  filterKey: 'filename'

  initialize: (@gist) ->
    super

    @setArray(_.values(gist.files))

  itemForElement: ({size, filename}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div filename, class: 'primary-line'
        @div humanize.filesize(size), class: 'secondary-line'

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()

  confirmed: (file) ->
    openGistFile(@gist, file)
    @cancel()
