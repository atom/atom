$ = require 'jquery'
coffeekup = require 'coffeekup'

module.exports =
class Template
  @buildView: (attributes) ->
    (new this).buildView(attributes)

  buildView: (attributes) ->
    $(coffeekup.render(@content, attributes))

