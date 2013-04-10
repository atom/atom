ConfigPanel = require 'config-panel'

describe "ConfigPanel", ->
  it "automatically binds named input fields to their corresponding config keys", ->
    class TestPanel extends ConfigPanel
      @content: ->
        @div =>
          @input outlet: 'intInput', name: 'foo.int', type: 'int'
          @input outlet: 'floatInput', name: 'foo.float', type: 'float'
          @input outlet: 'stringInput', name: 'foo.string', type: 'string'

    config.set('foo.int', 22)

    panel = new TestPanel
    expect(panel.intInput.val()).toBe '22'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe ''

    config.set('foo.int', 10)
    expect(panel.intInput.val()).toBe '10'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe ''

    config.set('foo.string', 'hey')
    expect(panel.intInput.val()).toBe '10'
    expect(panel.floatInput.val()).toBe ''
    expect(panel.stringInput.val()).toBe 'hey'

    panel.intInput.val('90.2').change()
    expect(config.get('foo.int')).toBe 90

    panel.floatInput.val('90.2').change()
    expect(config.get('foo.float')).toBe 90.2

    panel.stringInput.val('moo').change()
    expect(config.get('foo.string')).toBe 'moo'
