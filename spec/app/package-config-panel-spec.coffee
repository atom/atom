PackageConfigPanel = require 'package-config-panel'
packages = require 'packages'

describe "PackageConfigPanel", ->
  [panel, configObserver] = []

  beforeEach ->
    spyOn(packages, 'getAvailable').andCallFake (callback) ->
      available = [
        {
          name: 'p1'
          version: '3.2.1'
          homepage: 'http://p1.io'
        }
        {
          name: 'p2'
          version: '1.2.3'
          repository: url: 'http://github.com/atom/p2.git'
          bugs: url: 'http://github.com/atom/p2/issues'
        }
        {
          name: 'p3'
          version: '5.8.5'
        }
      ]
      callback(null, available)

    configObserver = jasmine.createSpy("configObserver")
    observeSubscription = config.observe('core.disabledPackages', configObserver)
    config.set('core.disabledPackages', ['toml', 'wrap-guide'])
    configObserver.reset()
    panel = new PackageConfigPanel

  describe 'Installed tab', ->
    it "lists all installed packages, with an unchecked checkbox next to packages in the core.disabledPackages array", ->
      treeViewTr = panel.installed.packageTableBody.find("tr[name='tree-view']")
      expect(treeViewTr).toExist()
      expect(treeViewTr.find("input[type='checkbox']").attr('checked')).toBeTruthy()

      tomlTr = panel.installed.packageTableBody.find("tr[name='toml']")
      expect(tomlTr).toExist()
      expect(tomlTr.find("input[type='checkbox']").attr('checked')).toBeFalsy()

      wrapGuideTr = panel.installed.packageTableBody.find("tr[name='wrap-guide']")
      expect(wrapGuideTr).toExist()
      expect(wrapGuideTr.find("input[type='checkbox']").attr('checked')).toBeFalsy()

    describe "when the core.disabledPackages array changes", ->
      it "updates the checkboxes for newly disabled / enabled packages", ->
        config.set('core.disabledPackages', ['wrap-guide', 'tree-view'])
        expect(panel.find("tr[name='tree-view'] input[type='checkbox']").attr('checked')).toBeFalsy()
        expect(panel.find("tr[name='toml'] input[type='checkbox']").attr('checked')).toBeTruthy()
        expect(panel.find("tr[name='wrap-guide'] input[type='checkbox']").attr('checked')).toBeFalsy()

    describe "when a checkbox is unchecked", ->
      it "adds the package name to the disabled packages array", ->
        panel.find("tr[name='tree-view'] input[type='checkbox']").attr('checked', false).change()
        expect(configObserver).toHaveBeenCalledWith(['toml', 'wrap-guide', 'tree-view'])

    describe "when a checkbox is checked", ->
      it "removes the package name from the disabled packages array", ->
        panel.find("tr[name='toml'] input[type='checkbox']").attr('checked', true).change()
        expect(configObserver).toHaveBeenCalledWith(['wrap-guide'])

  describe 'Available tab', ->
    it 'lists all available packages', ->
      panel.availableLink.click()
      panel.attachToDom()

      expect(panel.available.children('.panel').length).toBe 3
      p1View = panel.available.children('.panel:eq(0)').view()
      p2View = panel.available.children('.panel:eq(1)').view()
      p3View = panel.available.children('.panel:eq(2)').view()

      expect(p1View.name.text()).toBe 'p1'
      expect(p2View.name.text()).toBe 'p2'
      expect(p3View.name.text()).toBe 'p3'

      p1View.dropdownButton.click()
      expect(p1View.homepage).toBeVisible()
      expect(p1View.homepage.find('a').attr('href')).toBe 'http://p1.io'
      expect(p1View.issues).toBeHidden()

      p2View.dropdownButton.click()
      expect(p2View.homepage).toBeVisible()
      expect(p2View.homepage.find('a').attr('href')).toBe 'http://github.com/atom/p2'
      expect(p2View.issues).toBeVisible()
      expect(p2View.issues.find('a').attr('href')).toBe 'http://github.com/atom/p2/issues'

      p3View.dropdownButton.click()
      expect(p1View.homepage).toBeHidden()
      expect(p1View.issues).toBeHidden()
