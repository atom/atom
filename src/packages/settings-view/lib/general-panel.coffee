{$$, View} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
async = require 'async'
AtomPackage = require 'atom-package'
Editor = require 'editor'

###
# Internal #
###

module.exports =
class GeneralPanel extends View
  @content: ->
    @form id: 'general-panel', class: 'form-horizontal', =>
      @div outlet: "loadingElement", class: 'alert alert-info loading-area', "Loading settings"

  initialize: ->
    window.setTimeout (=> @activatePackages => @showSettings()), 1

  showSettings: ->
    @loadingElement.hide()
    @appendSettings(name, settings) for name, settings of config.getSettings()
    @bindFormFields()
    @bindEditors()

  activatePackages: (finishedCallback) ->
    iterator = (pack, callback) ->
      try
        if pack instanceof AtomPackage and not pack.isActive()
          pack.activate({immediate: true})
      catch e
        console.error e
      finally
        callback()

    async.each atom.getLoadedPackages(), iterator, finishedCallback

  appendSettings: (namespace, settings) ->
    return if _.isEmpty(settings)

    @append $$ ->
      @fieldset =>
        @legend "#{_.uncamelcase(namespace)} settings"
        appendSetting.call(this, namespace, name, value) for name, value of settings

  bindFormFields: ->
    for input in @find('input[id]').toArray()
      do (input) =>
        input = $(input)
        name = input.attr('id')
        type = input.attr('type')

        @observeConfig name, (value) ->
          if type is 'checkbox'
            input.attr('checked', value)
          else
            input.val(value) if value

        input.on 'change', =>
          value = input.val()
          if type == 'checkbox'
            value = !!input.attr('checked')
          else
            value = @parseValue(type, value)
          config.set(name, value)

  bindEditors: ->
    for editor in @find('.editor[id]').views()
      do (editor) =>
        name = editor.attr('id')
        type = editor.attr('type')

        @observeConfig name, (value) ->
          return if value?.toString() == editor.getText()
          value ?= ""
          editor.setText(value.toString())

        editor.getBuffer().on 'contents-modified', =>
          config.set(name, @parseValue(type, editor.getText()))

  parseValue: (type, value) ->
    if value == ''
      value = undefined
    else if type == 'int'
      intValue = parseInt(value)
      value = intValue unless isNaN(intValue)
    else if type == 'float'
      floatValue = parseFloat(value)
      value = floatValue unless isNaN(floatValue)

    value

###
# Space Pen Helpers
###

appendSetting = (namespace, name, value) ->
  @div class: 'control-group', =>
    @div class: 'controls', =>
      if _.isBoolean(value)
        appendCheckbox.call(this, namespace, name, value)
      else if _.isArray(value)
        appendArray.call(this, namespace, name, value)
      else
        appendEditor.call(this, namespace, name, value)

appendCheckbox = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  keyPath = "#{namespace}.#{name}"
  @div class: 'checkbox', =>
    @label for: keyPath, =>
      @input id: keyPath, type: 'checkbox'
      @text englishName

appendEditor = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  keyPath = "#{namespace}.#{name}"
  if _.isNumber(value)
    type = if value % 1 == 0 then 'int' else 'float'
  else
    type = 'string'

  @label class: 'control-label', englishName
  @div class: 'controls', =>
    @subview keyPath.replace('.', ''), new Editor(mini: true, attributes: {id: keyPath, type: type})

appendArray = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  @label class: 'control-label', englishName
  @div class: 'controls', =>
    @text "readOnly: " + value.join(", ")
