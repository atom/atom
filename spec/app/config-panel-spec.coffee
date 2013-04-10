ConfigPanel = require 'config-panel'

describe "ConfigPanel", ->
  it "automatically binds named input fields to their corresponding config keys", ->
    class TestPanel extends ConfigPanel
      @content: ->
        @div =>
          @input outlet: 'intInput', id: 'foo.int', type: 'int'
          @input outlet: 'floatInput', id: 'foo.float', type: 'float'
          @input outlet: 'stringInput', id: 'foo.string', type: 'string'
          @input outlet: 'booleanInput', id: 'foo.boolean', type: 'checkbox'

    config.set('foo.int', 22)
    config.set('foo.boolean', true)

    panel = new TestPanel
    expect(panel.intInput.val()).toBe '22'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe ''
    expect(panel.booleanInput.attr('checked')).toBeTruthy()

    config.set('foo.int', 10)
    expect(panel.intInput.val()).toBe '10'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe ''

    config.set('foo.string', 'hey')
    expect(panel.intInput.val()).toBe '10'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe 'hey'

    config.set('foo.boolean', false)
    expect(panel.booleanInput.attr('checked')).toBeFalsy()

    panel.intInput.val('90.2').change()
    expect(config.get('foo.int')).toBe 90

    panel.floatInput.val('90.2').change()
    expect(config.get('foo.float')).toBe 90.2

    panel.stringInput.val('moo').change()
    expect(config.get('foo.string')).toBe 'moo'
