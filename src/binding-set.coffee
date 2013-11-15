{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'
PEG = require 'pegjs'

### Internal ###

module.exports =
class BindingSet
  @nextBindingSetIndex: 0

  constructor: (selector, commandsByKeystroke, @name) ->
    @index = BindingSet.nextBindingSetIndex++
    keystrokePattern = fs.readFileSync(require.resolve('./keystroke-pattern.pegjs'), 'utf8')
    BindingSet.parser ?= PEG.buildParser(keystrokePattern)
    @specificity = specificity(selector)
    @selector = selector.replace(/!important/g, '')
