{$$} = require 'space-pen'
SelectList = require 'select-list'
{getAvailablePeople} = require './presence-utils'

module.exports =
class BuddyList extends SelectList
  @viewClass: -> "#{super} peoples-view overlay from-top"

  filterKey: 'name'

  initialize: ->
    super

    @setArray(getAvailablePeople())
    @attach()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()

  itemForElement: ({info}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div info.login, class: 'primary-line'
        @div info.name, class: 'secondary-line'
