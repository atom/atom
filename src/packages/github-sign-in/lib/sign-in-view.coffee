$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
keytar = require 'keytar'

class SignInView extends ScrollView
  @content: ->
    @div class: 'sign-in-view overlay from-top', =>
      @h4 'Sign in to GitHub'
      @p 'Your password will only be used to generate a token that will be stored in your keychain.'
      @div class: 'form-inline', =>
        @input outlet: 'username', type: 'text', placeholder: 'Username or Email', tabindex: 1
        @input outlet: 'password', type: 'password', placeholder: 'Password', tabindex: 2
        @button outlet: 'signIn', class: 'btn', disabled: 'disabled', tabindex: 3, 'Sign in'
        @button outlet: 'cancel', class: 'btn', tabindex: 4, 'Cancel'
      @div outlet: 'alert', class: 'alert alert-error'

  initialize: ({@signedInUser}={})->
    rootView.on 'github:sign-in', (event, @signedInEventHandler) => @attach()

    @username.on 'core:confirm', => @generateOAuth2Token()
    @username.on 'input', => @validate()

    @password.on 'core:confirm', => @generateOAuth2Token()
    @password.on 'input', => @validate()

    @signIn.on 'core:confirm', => @generateOAuth2Token()
    @signIn.on 'click', => @generateOAuth2Token()

    @cancel.on 'core:confirm', => @generateOAuth2Token()

    @cancel.on 'click', => @detach()
    @on 'core:cancel', => @detach()

    @subscribe $(document.body), 'click focusin', (e) =>
      @detach() unless $.contains(this[0], e.target)

  serialize: -> {@signedInUser}

  validate: ->
    if $.trim(@username.val()).length > 0 and @password.val().length > 0
      @signIn.enable()
    else
      @signIn.disable()

  generateOAuth2Token: ->
    return if @signIn.isDisabled()

    @alert.hide()
    @username.disable()
    @password.disable()
    @signIn.disable()

    username = $.trim(@username.val())
    credentials = btoa("#{username}:#{@password.val()}")
    request =
      scopes: ['user', 'repo', 'gist']
      note: 'GitHub Atom'
      note_url: 'https://github.com/github/atom'
    $.ajax
      url: 'https://api.github.com/authorizations'
      type: 'POST'
      dataType: 'json'
      contentType: 'application/json; charset=UTF-8'
      data: JSON.stringify(request)

      beforeSend: (xhr) ->
        xhr.setRequestHeader('Authorization', "Basic #{credentials}")

      success: ({token}={}) =>
        if token?.length > 0
          @signedInUser = username
          if keytar.replacePassword('github.com', 'github', token)
            @signedInEventHandler?.trigger?('github:signed-in')
          else
            console.warn 'Unable to save GitHub token to keychain'
        @detach()

      error: (response={}) =>
        if _.isString(response.responseText)
          try
            message = JSON.parse(response.responseText)?.message
        else
          message = response.responseText?.message
        message ?= ''
        @alert.text(message).show()
        @username.enable()
        @password.enable()
        @signIn.enable()
        @password.focus()

  attach: ->
    if @signedInUser?
      @username.val(@signedInUser)
    else
      @username.val('')
    @password.val('')
    @username.enable()
    @password.enable()
    @alert.hide()

    rootView.append(this)

    if @signedInUser?
      @password.focus()
    else
      @username.focus()

  detach: ->
    super

    @signedInEventHandler = null

module.exports =
  signInView: null

  activate: (state) ->
    @signInView = new SignInView(state)

  deactivate: ->
    @signInView?.remove()
    @signInView = null

  serialize: ->
    if @signInView?
      @signInView.serialize()
    else
      @state
