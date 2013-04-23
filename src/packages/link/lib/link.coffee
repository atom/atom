module.exports =
  activate: ->
    rootView.command 'link:open', ->
      editSession = rootView.getActivePaneItem()
      return unless editSession?

      token = editSession.tokenForBufferPosition(editSession.getCursorBufferPosition())
      return unless token?

      unless @selector?
        TextMateScopeSelector = require 'text-mate-scope-selector'
        @selector = new TextMateScopeSelector('markup.underline.link')

      if @selector.matches(token.scopes)
        ChildProcess = require 'child_process'
        ChildProcess.spawn 'open', [token.value]
