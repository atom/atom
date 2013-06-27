SettingsPanel = require '../lib/settings-panel'
Editor = require 'editor'

getValueForId = (panel, id) ->
  element = panel.find("##{id.replace('.', '\\.')}")
  if element.is("input")
    element.attr('checked')?
  else
    element.view().getText()

setValueForId = (panel, id, value) ->
  element = panel.find("##{id.replace('.', '\\.')}")
  if element.is("input")
    element.attr('checked', if value then 'checked' else '')
    element.change()
  else
    element.view().setText(value?.toString())
    window.advanceClock(10000) # wait for contents-modified to be triggered


describe "SettingsPanel", ->
  it "automatically binds named fields to their corresponding config keys", ->
    config.set('foo.int', 22)
    config.set('foo.float', 0.1)
    config.set('foo.boolean', true)
    config.set('foo.string', 'hey')

    panel = new SettingsPanel()
    expect(getValueForId(panel, 'foo.int')).toBe '22'
    expect(getValueForId(panel, 'foo.float')).toBe '0.1'
    expect(getValueForId(panel, 'foo.boolean')).toBeTruthy()
    expect(getValueForId(panel, 'foo.string')).toBe 'hey'

    config.set('foo.int', 222)
    config.set('foo.float', 0.11)
    config.set('foo.boolean', false)
    config.set('foo.string', 'hey again')
    expect(getValueForId(panel, 'foo.int')).toBe '222'
    expect(getValueForId(panel, 'foo.float')).toBe '0.11'
    expect(getValueForId(panel, 'foo.boolean')).toBeFalsy()
    expect(getValueForId(panel, 'foo.string')).toBe 'hey again'

    setValueForId(panel, 'foo.int', 90)
    setValueForId(panel, 'foo.float', 89.2)
    setValueForId(panel, 'foo.string', "oh hi")
    setValueForId(panel, 'foo.boolean', true)
    expect(config.get('foo.int')).toBe 90
    expect(config.get('foo.float')).toBe 89.2
    expect(config.get('foo.boolean')).toBe true
    expect(config.get('foo.string')).toBe 'oh hi'

    setValueForId(panel, 'foo.int', '')
    setValueForId(panel, 'foo.float', '')
    setValueForId(panel, 'foo.string', '')
    expect(config.get('foo.int')).toBeUndefined()
    expect(config.get('foo.float')).toBeUndefined()
    expect(config.get('foo.string')).toBeUndefined()

  it "does not save the config value until it has been changed to a new value", ->
    config.set('foo.int', 1)

    observeHandler = jasmine.createSpy("observeHandler")
    config.observe "foo.int", observeHandler
    observeHandler.reset()

    testPanel = new SettingsPanel
    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(observeHandler).not.toHaveBeenCalled()

    setValueForId(testPanel, 'foo.int', 2)
    expect(observeHandler).toHaveBeenCalled()
    observeHandler.reset()

    setValueForId(testPanel, 'foo.int', 2)
    expect(observeHandler).not.toHaveBeenCalled()
