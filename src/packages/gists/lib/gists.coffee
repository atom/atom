$ = require 'jquery'
{$$} = require 'space-pen'

module.exports =
class Gists
  @activate: -> new Gists

  constructor: ->
    rootView.command 'gist:create', '.editor', => @createGist()

  createGist: ->
    editor = rootView.getActiveView()
    return unless editor?

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
          @div class: 'notification', =>
            @span class: 'icon icon-gist mega-icon'
            @div class: 'content', =>
              @h3 "Gist #{response.id} created", class: 'title'
              @p "The url is on your clipboard", class: 'message'
        rootView.append(notification.hide())
        notification.fadeIn().delay(2000).fadeOut(complete: -> $(this).remove())
