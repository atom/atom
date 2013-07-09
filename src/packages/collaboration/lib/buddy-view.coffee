url = require 'url'
{View} = require 'space-pen'

module.exports =
class BuddyView extends View
  @content: ({user, windows}) ->
    @div =>
      @div class: 'buddy-name', =>
        @img class: 'avatar', outlet: 'avatar'
        @span user.login

        for id, windowState of windows
          {repository} = windowState
          continue unless repository?
          [owner, name] = url.parse(repository.url).path.split('/')[-2..]
          name = name.replace(/\.git$/, '')
          @div class: 'repo-name', =>
            @span name
          if repository.branch
            @div class: 'branch-name', =>
              @span repository.branch

  initialize: (@buddy) ->
    if @buddy.user.avatarUrl
      @avatar.attr('src', @buddy.user.avatarUrl)
    else
      @avatar.hide()
