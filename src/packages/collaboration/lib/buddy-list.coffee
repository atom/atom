url = require 'url'
{$$} = require 'space-pen'
ScrollView = require 'scroll-view'
BuddyView = require './buddy-view'

module.exports =
class BuddyList extends ScrollView
  @content: ->
    @div class: 'buddy-list', tabindex: -1

  initialize: (@presence) ->
    super

    @presence.on 'person-added', -> @updateBuddies()
    @presence.on 'person-removed', -> @updateBuddies()
    @presence.on 'person-status-changed', -> @updateBuddies()

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
    @updateBuddies()

  updateBuddies: ->
    @empty()
    @append(new BuddyView(buddy)) for buddy in @presence.getPeople()
