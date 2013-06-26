ConfigPanel = require './config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

###
# Internal #
###

Editor = require 'editor'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @form id: 'general-config-panel', class: 'form-horizontal', =>

  form: null

  initialize: ->
    @appendSettings(namespace, settings) for namespace, settings of config.getSettings()
    super

  appendSettings: (namespace, settings) ->
    return if _.isEmpty(settings)

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
      type = if _.isNumber(value) then 'number' else 'string'
      @label class: 'control-label', englishName
      @div class: 'controls', =>
        @subview keyPath.replace('.', ''), new Editor(mini: true, attributes: {id: keyPath, type: type})

    appendArray = (namespace, name, value) ->
      englishName = _.uncamelcase(name)
      @label class: 'control-label', englishName
      @div class: 'controls', =>
        @text value.join(", ")

    @append $$ ->
      @fieldset =>
        @legend "#{_.uncamelcase(namespace)} settings"
        appendSetting.call(this, namespace, name, value) for name, value of settings
