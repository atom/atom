$ = require 'jquery'
{View} = require 'space-pen'

###
# Internal #
###

module.exports =
class ConfigPanel extends View
  initialize: ->
    @bindFormFields()
    @bindEditors()

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
    switch type
      when 'int'
        intValue = parseInt(value)
        value = intValue unless isNaN(intValue)
      when 'float'
        floatValue = parseFloat(value)
        value = floatValue unless isNaN(floatValue)
    value = undefined if value == ''
    value
