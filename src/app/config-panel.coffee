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
        @observeConfig name, (value) -> input.val(value) if value
        input.on 'change', ->
          value = input.val()
          config.set name, switch type
            when 'int'
              parseInt(value)
            when 'float'
              parseFloat(value)
            else
              value
