$ = require 'jquery'
{$$} = require 'space-pen'
gistUtils = require './gist-utils'

module.exports =
class CreateGist
  createGist: ->
    editor = rootView.getActiveView()
    return unless editor?

    buffer = editor.getBuffer?()
    return unless buffer?

    gist = { public: false, files: {} }
    gist.files[buffer.getBaseName()] =
      content: editor.getSelectedText() or editor.getText()

    gistUtils.createGist gist, (error, createdGist) ->
      if error?
        console.error("Error creating Gist", error.stack ? error)
      else
        pasteboard.write(createdGist.html_url)
        notification = $$ ->
          @div class: 'notification', =>
            @span class: 'icon icon-gist mega-icon'
            @div class: 'content', =>
              @h3 "Gist #{createdGist.id} created", class: 'title'
              @p "The url is on your clipboard", class: 'message'
        rootView.append(notification.hide())
        notification.fadeIn().delay(2000).fadeOut(complete: -> $(this).remove())
