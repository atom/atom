$ = require 'jquery'
{View} = require 'space-pen'

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
        input.on 'change', ->
          value = input.val()
          config.set name, switch type
            when 'int'
              parseInt(value)
            when 'float'
              parseFloat(value)
            when 'checkbox'
              !!input.attr('checked')
            else
              value

  bindEditors: ->
    for editor in @find('.editor[id]').views()
      console.log editor
      do (editor) =>
        name = editor.attr('id')
        type = editor.attr('type')

        @observeConfig name, (value) ->
          editor.setText(value.toString())

        editor.getBuffer().on 'contents-modified', ->
          value = editor.getText()
          if type == 'int' then value = parseInt(value) or 0
          if type == 'float' then value = parseFloat(value) or 0
          config.set name, value
