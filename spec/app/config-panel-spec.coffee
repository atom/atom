ConfigPanel = require 'config-panel'
Editor = require 'editor'

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

  it "automatically binds named editors to their corresponding config keys", ->
    class TestPanel extends ConfigPanel
      @content: ->
        @div =>
          @subview 'intEditor', new Editor(mini: true, attributes: { id: 'foo.int', type: 'int' })
          @subview 'floatEditor', new Editor(mini: true, attributes: { id: 'foo.float', type: 'float' })
          @subview 'stringEditor', new Editor(mini: true, attributes: { id: 'foo.string', type: 'string' })

    config.set('foo.int', 1)
    config.set('foo.float', 1.1)
    config.set('foo.string', 'I think therefore I am.')
    panel = new TestPanel
    expect(panel.intEditor.getText()).toBe '1'
    expect(panel.floatEditor.getText()).toBe '1.1'
    expect(panel.stringEditor.getText()).toBe 'I think therefore I am.'

    config.set('foo.int', 2)
    config.set('foo.float', 2.2)
    config.set('foo.string', 'We are what we think.')
    expect(panel.intEditor.getText()).toBe '2'
    expect(panel.floatEditor.getText()).toBe '2.2'
    expect(panel.stringEditor.getText()).toBe 'We are what we think.'

    panel.intEditor.setText('3')
    panel.floatEditor.setText('3.3')
    panel.stringEditor.setText('All limitations are self imposed.')
    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(config.get('foo.int')).toBe 3
    expect(config.get('foo.float')).toBe 3.3
    expect(config.get('foo.string')).toBe 'All limitations are self imposed.'

    panel.intEditor.setText('')
    panel.floatEditor.setText('ha ha')
    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(config.get('foo.int')).toBe 0
    expect(config.get('foo.float')).toBe 0
