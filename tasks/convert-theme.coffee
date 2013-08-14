path = require 'path'

_ = require 'underscore'
plist = require 'plist'
{ScopeSelector} = require 'first-mate'

module.exports = (grunt) ->
  grunt.registerTask 'convert-theme', 'Convert a TextMate theme to an Atom theme', ->
    if textMateThemePath = grunt.option('path')
      textMateThemePath = path.resolve(textMateThemePath)
      if grunt.file.isFile(textMateThemePath)
        textMateTheme = new TextMateTheme(textMateThemePath)
        themeName = path.basename(textMateThemePath, path.extname(textMateThemePath))
        atomThemePath = path.join(path.dirname(textMateThemePath), "#{themeName.toLowerCase()}-syntax.css")
        grunt.file.write(atomThemePath, textMateTheme.getStylesheet())
        grunt.log.ok("Atom theme written to: #{atomThemePath}")
      else
        grunt.log.error("No theme file found at: #{textMateThemePath}")
        false
    else
      grunt.log.error('Must specify --path=<path to TextMate theme>')
      false

class TextMateTheme
  constructor: (@path) ->
    @rulesets = []
    @buildRulesets()

  buildRulesets: ->
    {settings} = plist.parseFileSync(@path)
    @buildGlobalSettingsRulesets(settings[0])
    @buildScopeSelectorRulesets(settings[1..])

  getStylesheet: ->
    lines = []
    for {selector, properties} in @getRulesets()
      lines.push("#{selector} {")
      lines.push "  #{name}: #{value};" for name, value of properties
      lines.push("}\n")
    lines.join('\n')

  getRulesets: -> @rulesets

  buildGlobalSettingsRulesets: ({settings}) ->
    { background, foreground, caret, selection, lineHighlight } = settings

    @rulesets.push
      selector: '.editor, .editor .gutter'
      properties:
        'background-color': @translateColor(background)
        'color': @translateColor(foreground)

    @rulesets.push
      selector: '.editor.is-focused .cursor'
      properties:
        'border-color': @translateColor(caret)

    @rulesets.push
      selector: '.editor.is-focused .selection .region'
      properties:
        'background-color': @translateColor(selection)

    @rulesets.push
      selector: '.editor.is-focused .line-number.cursor-line-no-selection, .editor.is-focused .line.cursor-line'
      properties:
        'background-color': @translateColor(lineHighlight)

  buildScopeSelectorRulesets: (scopeSelectorSettings) ->
    for { name, scope, settings } in scopeSelectorSettings
      continue unless scope
      @rulesets.push
        comment: name
        selector: @translateScopeSelector(scope)
        properties: @translateScopeSelectorSettings(settings)

  translateScopeSelector: (textmateScopeSelector) ->
    new ScopeSelector(textmateScopeSelector).toCssSelector()

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
      a = Math.round((a / 255.0) * 100) / 100

      "rgba(#{r}, #{g}, #{b}, #{a})"
