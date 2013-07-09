url = require 'url'
{View} = require 'space-pen'

module.exports =
class BuddyView extends View
  @content: ({user, state}) ->
    @div =>
      @div class: 'buddy-name', =>
        @img class: 'avatar', outlet: 'avatar'
        @span user.login
      if state.repository
        [owner, name] = url.parse(state.repository.url).path.split('/')[-2..]
        name = name.replace(/\.git$/, '')
        @div class: 'repo-name', =>
          @span name
        if state.repository.branch
          @div class: 'branch-name', =>
            @span state.repository.branch

  initialize: (@buddy) ->
    if @buddy.user.avatarUrl
      @avatar.attr('src', @buddy.user.avatarUrl)
    else
      @avatar.hide()
