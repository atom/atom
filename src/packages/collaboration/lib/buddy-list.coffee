url = require 'url'
{$$} = require 'space-pen'
SelectList = require 'select-list'
{getAvailablePeople} = require './presence-utils'

module.exports =
class BuddyList extends SelectList
  @viewClass: -> "#{super} peoples-view overlay from-top"

  filterKey: 'filterText'

  initialize: ->
    super

    people = getAvailablePeople()
    people.forEach (person) ->
      segments = []
      segments.push(person.user.login)
      segments.push(person.user.name) if person.user.name
      person.filterText = segments.join(' ')
    @setArray(people)
    @attach()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()

  itemForElement: ({user, state}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div "#{user.login} (#{user.name})", class: 'primary-line'
        if state.repository
          [owner, name] = url.parse(state.repository.url).path.split('/')[-2..]
          name = name.replace(/\.git$/, '')
          @div "#{owner}/#{name}@#{state.repository.branch}", class: 'secondary-line'
