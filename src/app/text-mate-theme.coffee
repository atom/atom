_ = require 'underscore'

module.exports =
class TextMateTheme
  constructor: ({@name, settings}) ->
    @rulesets = []
    globalSettings = settings[0]
    @buildGlobalSettingsRulesets(settings[0])
    @buildScopeSelectorRulesets(settings[1..])

  getRulesets: -> @rulesets

  buildGlobalSettingsRulesets: ({settings}) ->
    { background, foreground, caret, selection } = settings

    @rulesets.push
      selector: '.editor'
      properties:
        'background-color': @translateColor(background)
        'color': @translateColor(foreground)

    @rulesets.push
      selector: '.editor.focused .cursor'
      properties:
        'border-color': @translateColor(caret)

    @rulesets.push
      selector: '.editor.focused .selection'
      properties:
        'background-color': @translateColor(selection)

  buildScopeSelectorRulesets: (scopeSelectorSettings) ->
    for { name, scope, settings } in scopeSelectorSettings
      continue unless scope
      @rulesets.push
        comment: name
        selector: @translateScopeSelector(scope)
        properties: @translateScopeSelectorSettings(settings)

  translateScopeSelector: (textmateScopeSelector) ->
    textmateScopeSelector.replace('.', '--')

  translateScopeSelectorSettings: ({ foreground, background, fontStyle }) ->
    properties = {}

    if fontStyle
      fontStyles = fontStyle.split(/\s+/)
      properties['font-weight'] = 'bold' if _.contains(fontStyles, 'bold')
      properties['font-style'] = 'italic' if _.contains(fontStyles, 'italic')
      properties['text-decoration'] = 'underline' if _.contains(fontStyles, 'underline')

    properties['color'] = @translateColor(foreground) if foreground
    properties['background-color'] = @translateColor(background) if background
    properties

  translateColor: (textmateColor) ->
    if textmateColor.length <= 7
      textmateColor
    else
      r = parseInt(textmateColor[1..2], 16)
      g = parseInt(textmateColor[3..4], 16)
      b = parseInt(textmateColor[5..6], 16)
      a = parseInt(textmateColor[7..8], 16)
      "rgba(#{r}, #{g}, #{b}, #{a})"
