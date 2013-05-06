$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
keytar = require 'keytar'

module.exports =
class SignInView extends ScrollView
  @activate: ->
    new SignInView()

  @content: ->
    @div class: 'sign-in-view overlay from-top', =>
      @h4 'Sign in to GitHub'
      @p 'Your password will only be used to generate a token that will be stored in your keychain.'
      @div class: 'form-inline', =>
        @input outlet: 'username', type: 'text', placeholder: 'Username or Email'
        @input outlet: 'password', type: 'password', placeholder: 'Password'
        @button outlet: 'signIn', class: 'btn', disabled: 'disabled', 'Sign in'
        @button outlet: 'cancel', class: 'btn', 'Cancel'
      @div outlet: 'alert', class: 'alert alert-error'

  initialize: ->
    rootView.command 'github:sign-in', => @attach()

    @username.on 'next-field', => @password.focus()
    @username.on 'core:confirm', => @generateOAuth2Token()
    @username.on 'input', => @validate()

    @password.on 'next-field', =>
      if @isElementEnabled(@signIn)
        @signIn.focus()
      else
        @cancel.focus()
    @password.on 'core:confirm', => @generateOAuth2Token()
    @password.on 'input', => @validate()

    @signIn.on 'next-field', => @cancel.focus()
    @signIn.on 'core:confirm', => @generateOAuth2Token()
    @signIn.on 'click', => @generateOAuth2Token()

    @cancel.on 'next-field', => @username.focus()
    @cancel.on 'core:confirm', => @generateOAuth2Token()

    @cancel.on 'click', => @detach()
    @on 'core:cancel', => @detach()

    @subscribe $(document.body), 'click', (e) =>
      @detach() unless $.contains(this[0], e.target)

    @subscribe $(document.body), 'focusin', (e) =>
      @detach() unless $.contains(this[0], e.target)

  validate: ->
    canSignIn = $.trim(@username.val()).length > 0 and @password.val().length > 0
    @setElementEnabled(@signIn, canSignIn)

  setElementEnabled: (element, enabled=true) ->
    if enabled
      element.removeAttr('disabled')
    else
      element.attr('disabled', 'disabled')

  isElementEnabled: (element) ->
    element.attr('disabled') isnt 'disabled'

  generateOAuth2Token: ->
    return unless @isElementEnabled(@signIn)

    @alert.hide()
    @setElementEnabled(@username, false)
    @setElementEnabled(@password, false)
    @setElementEnabled(@signIn, false)

    credentials = btoa("#{$.trim(@username.val())}:#{@password.val()}")
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
          unless keytar.replacePassword('GitHub.com', 'github', token)
            console.log 'Unable to save GitHub.com token to keychain'
        @detach()

      error: (response) =>
        if _.isString(response.responseText)
          try
            message = JSON.parse(response.responseText)?.message
          catch e
            message = ''
        else
          message = response.responseText?.message
        message ?= ''
        @alert.text(message).show()

  attach: ->
    @username.val('')
    @password.val('')
    @setElementEnabled(@username, true)
    @setElementEnabled(@password, true)
    @alert.hide()
    rootView.append(this)
    @username.focus()
