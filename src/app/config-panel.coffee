$ = require 'jquery'
{View} = require 'space-pen'

module.exports =
class ConfigPanel extends View
  initialize: ->
    @bindFormFields()

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
