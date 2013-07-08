url = require 'url'
{View} = require 'space-pen'

module.exports =
class BuddyView extends View
  @content: ({user, state}) ->
    @div class: 'two-lines', =>
      @div "#{user.login} (#{user.name})"
      if state.repository
        [owner, name] = url.parse(state.repository.url).path.split('/')[-2..]
        name = name.replace(/\.git$/, '')
        @div "#{owner}/#{name}@#{state.repository.branch}"

  initialize: (@buddy) ->
