$ = require 'jquery'
{$$} = require 'space-pen'

module.exports =
class Gists

  @activate: (rootView) -> new Gists(rootView)

  constructor: (@rootView) ->

  createGist: (editor) ->
    gist = { public: false, files: {} }
    gist.files[editor.getBuffer().getBaseName()] =
      content: editor.getSelectedText() or editor.getText()

    $.ajax
      url: 'https://api.github.com/gists'
      type: 'POST'
      dataType: 'json'
      contentType: 'application/json; charset=UTF-8'
      data: JSON.stringify(gist)
      success: (response) =>
        pasteboard.write(response.html_url)
        notification = $$ ->
          @div class: 'gist-notification', =>
            @div class: 'message-area', =>
              @span "Gist #{response.id} created", class: 'message'
              @br()
              @span "The url is on your clipboard", class: 'clipboard'
        @rootView.append(notification.hide())
        notification.fadeIn().delay(2000).fadeOut(complete: -> $(this).remove())
