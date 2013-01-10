$ = require 'jquery'
{$$} = require 'space-pen'

module.exports =
  activate: (rootView) ->
    rootView.command 'gist:create', '.editor', (e) =>
      @createGist(e.currentTargetView())

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
      success: (response) ->
        pasteboard.write(response.html_url)
        notification = $$ ->
          @div "Gist #{response.id} created", class: 'gist-notification'
        rootView.append(notification.hide())
        notification.fadeIn().delay(1800).fadeOut(complete: -> $(this).remove())
