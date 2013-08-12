module.exports =
  activate: ->
    rootView.command 'link:open', ->
      editSession = rootView.getActivePaneItem()
      return unless editSession?

      token = editSession.tokenForBufferPosition(editSession.getCursorBufferPosition())
      return unless token?

      unless @selector?
        {ScopeSelector} = require 'first-mate'
        @selector = new ScopeSelector('markup.underline.link')

      if @selector.matches(token.scopes)
        require('shell').openExternal token.value
