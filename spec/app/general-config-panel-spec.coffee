GeneralConfigPanel = require 'general-config-panel'

fdescribe "GeneralConfigPanel", ->
  [panel, configObserver, observeSubscription] = []

  beforeEach ->
    configObserver = jasmine.createSpy("configObserver")
    config.set('core.disabledPackages', ['toml', 'wrap-guide'])
    observeSubscription = config.observe('core.disabledPackages', configObserver)
    configObserver.reset()
    panel = new GeneralConfigPanel

  afterEach ->
    observeSubscription.cancel()

  describe "available / disabled packages", ->
    it "lists all available packages, with an unchecked checkbox next to packages in the core.disabledPackages array", ->
      treeViewLi = panel.packageList.find("li[name='tree-view']")
      expect(treeViewLi).toExist()
      expect(treeViewLi.find("input[type='checkbox']").attr('checked')).toBeTruthy()

      tomlLi = panel.packageList.find("li[name='toml']")
      expect(tomlLi).toExist()
      expect(tomlLi.find("input[type='checkbox']").attr('checked')).toBeFalsy()

      wrapGuideLi = panel.packageList.find("li[name='wrap-guide']")
      expect(wrapGuideLi).toExist()
      expect(wrapGuideLi.find("input[type='checkbox']").attr('checked')).toBeFalsy()

    describe "when the core.disabledPackages array changes", ->
      it "updates the checkboxes for newly disabled / enabled packages", ->
        config.set('core.disabledPackages', ['wrap-guide', 'tree-view'])
        expect(panel.find("li[name='tree-view'] input[type='checkbox']").attr('checked')).toBeFalsy()
        expect(panel.find("li[name='toml'] input[type='checkbox']").attr('checked')).toBeTruthy()
        expect(panel.find("li[name='wrap-guide'] input[type='checkbox']").attr('checked')).toBeFalsy()

    describe "when a checkbox is unchecked", ->
      fit "adds the package name to the disabled packages array", ->
        panel.find("li[name='tree-view'] input[type='checkbox']").attr('checked', false).change()
        expect(configObserver).toHaveBeenCalledWith(['toml', 'wrap-guide', 'tree-view'])

    describe "when a checkbox is checked", ->
      it "removes the package name from the disabled packages array", ->
        panel.find("li[name='toml'] input[type='checkbox']").attr('checked', true).change()
        expect(configObserver).toHaveBeenCalledWith(['wrap-guide'])
