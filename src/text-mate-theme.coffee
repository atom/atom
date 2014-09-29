_ = require 'underscore-plus'
plist = require 'plist'
{ScopeSelector} = require 'first-mate'

module.exports =
class TextMateTheme
  constructor: (@contents) ->
    @rulesets = []
    @buildRulesets()

  buildRulesets: ->
    {settings} = plist.parseStringSync(@contents) ? {}
    settings ?= []

    for setting in settings
      {scope, name} = setting.settings
      continue if scope or name

      # Require all of these or invalid LESS will be generated if any required
      # variable value is missing
      {background, foreground, caret, selection, invisibles, lineHighlight} = setting.settings
      if background and foreground and caret and selection and lineHighlight and invisibles
        variableSettings = setting.settings
        break

    unless variableSettings?
      throw new Error """
        Could not find the required color settings in the theme.

        The theme being converted must contain a settings array with all of the following keys:
          * background
          * caret
          * foreground
          * invisibles
          * lineHighlight
          * selection
      """

    @buildSyntaxVariables(variableSettings)
    @buildGlobalSettingsRulesets(variableSettings)
    @buildScopeSelectorRulesets(settings)

  getStylesheet: ->
    lines = [
      '@import "syntax-variables";'
      ''
    ]
    for {selector, properties} in @getRulesets()
      lines.push("#{selector} {")
      lines.push "  #{name}: #{value};" for name, value of properties
      lines.push("}\n")
    lines.join('\n')

  getRulesets: -> @rulesets

  getSyntaxVariables: -> @syntaxVariables

  buildSyntaxVariables: (settings) ->
    @syntaxVariables = SyntaxVariablesTemplate
    for key, value of settings
      replaceRegex = new RegExp("\\{\\{#{key}\\}\\}", 'g')
      @syntaxVariables = @syntaxVariables.replace(replaceRegex, @translateColor(value))
    @syntaxVariables

  buildGlobalSettingsRulesets: (settings) ->
    @rulesets.push
      selector: '.editor'
      properties:
        'background-color': '@syntax-background-color'
        'color': '@syntax-text-color'

    @rulesets.push
      selector: '.editor .gutter'
      properties:
        'background-color': '@syntax-gutter-background-color'
        'color': '@syntax-gutter-text-color'

    @rulesets.push
      selector: '.editor .gutter .line-number.cursor-line'
      properties:
        'background-color': '@syntax-gutter-background-color-selected'
        'color': '@syntax-gutter-text-color-selected'

    @rulesets.push
      selector: '.editor .gutter .line-number.cursor-line-no-selection'
      properties:
        'color': '@syntax-gutter-text-color-selected'

    @rulesets.push
      selector: '.editor .wrap-guide'
      properties:
        'color': '@syntax-wrap-guide-color'

    @rulesets.push
      selector: '.editor .indent-guide'
      properties:
        'color': '@syntax-indent-guide-color'

    @rulesets.push
      selector: '.editor .invisible-character'
      properties:
        'color': '@syntax-invisible-character-color'

    @rulesets.push
      selector: '.editor .search-results .marker .region'
      properties:
        'background-color': 'transparent'
        'border': '@syntax-result-marker-color'

    @rulesets.push
      selector: '.editor .search-results .marker.current-result .region'
      properties:
        'border': '@syntax-result-marker-color-selected'

    @rulesets.push
      selector: '.editor.is-focused .cursor'
      properties:
        'border-color': '@syntax-cursor-color'

    @rulesets.push
      selector: '.editor.is-focused .selection .region'
      properties:
        'background-color': '@syntax-selection-color'

    @rulesets.push
      selector: '.editor.is-focused .line-number.cursor-line-no-selection, .editor.is-focused .line.cursor-line'
      properties:
        'background-color': @translateColor(settings.lineHighlight)

  buildScopeSelectorRulesets: (scopeSelectorSettings) ->
    for {name, scope, settings} in scopeSelectorSettings
      continue unless scope
      @rulesets.push
        comment: name
        selector: @translateScopeSelector(scope)
        properties: @translateScopeSelectorSettings(settings)

  translateScopeSelector: (textmateScopeSelector) ->
    new ScopeSelector(textmateScopeSelector).toCssSelector()

  translateScopeSelectorSettings: ({foreground, background, fontStyle}) ->
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
    textmateColor = "##{textmateColor.replace(/^#+/, '')}"
    if textmateColor.length <= 7
      textmateColor
    else
      r = @parseHexColor(textmateColor[1..2])
      g = @parseHexColor(textmateColor[3..4])
      b = @parseHexColor(textmateColor[5..6])
      a = @parseHexColor(textmateColor[7..8])
      a = Math.round((a / 255.0) * 100) / 100

      "rgba(#{r}, #{g}, #{b}, #{a})"

  parseHexColor: (color) ->
    parsed = Math.min(255, Math.max(0, parseInt(color, 16)))
    if isNaN(parsed)
      0
    else
      parsed

SyntaxVariablesTemplate = """
  // This defines all syntax variables that syntax themes must implement when they
  // include a syntax-variables.less file.

  // General colors
  @syntax-text-color: {{foreground}};
  @syntax-cursor-color: {{caret}};
  @syntax-selection-color: {{selection}};
  @syntax-background-color: {{background}};

  // Guide colors
  @syntax-wrap-guide-color: {{invisibles}};
  @syntax-indent-guide-color: {{invisibles}};
  @syntax-invisible-character-color: {{invisibles}};

  // For find and replace markers
  @syntax-result-marker-color: {{invisibles}};
  @syntax-result-marker-color-selected: {{foreground}};

  // Gutter colors
  @syntax-gutter-text-color: {{foreground}};
  @syntax-gutter-text-color-selected: {{foreground}};
  @syntax-gutter-background-color: {{background}};
  @syntax-gutter-background-color-selected: {{lineHighlight}};

  // For git diff info. i.e. in the gutter
  // These are static and were not extracted from your textmate theme
  @syntax-color-renamed: #96CBFE;
  @syntax-color-added: #A8FF60;
  @syntax-color-modified: #E9C062;
  @syntax-color-removed: #CC6666;
"""
