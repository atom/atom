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

  parseValue: (type, value) ->
    switch type
      when 'int' then value = parseInt(value) or value
      when 'float' then value = parseFloat(value) or value
    value = undefined if value == ''
    value

  bindEditors: ->
    for editor in @find('.editor[id]').views()
      do (editor) =>
        name = editor.attr('id')
        type = editor.attr('type')

        @observeConfig name, (value) ->
          return if value?.toString() == editor.getText()
          value ?= ""
          editor.setText(value.toString())

        editor.getBuffer().one 'contents-modified', =>
          editor.getBuffer().on 'contents-modified', =>
            config.set(name, @parseValue(type, editor.getText()))
