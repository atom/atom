PackageConfigPanel = require 'package-config-panel'
packageManager = require 'package-manager'

describe "PackageConfigPanel", ->
  [panel, configObserver] = []

  beforeEach ->
    packages = [
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

    spyOn(packageManager, 'getAvailable').andCallFake (callback) ->
      callback(null, packages)
    spyOn(packageManager, 'uninstall').andCallFake (pack, callback) ->
      callback()

    spyOn(atom, 'getAvailablePackageMetadata').andReturn(packages)
    spyOn(atom, 'resolvePackagePath').andCallFake (name) ->
      "/tmp/atom-packages/#{name}"

    configObserver = jasmine.createSpy("configObserver")
    observeSubscription = config.observe('core.disabledPackages', configObserver)
    config.set('core.disabledPackages', ['p1', 'p3'])
    configObserver.reset()
    jasmine.unspy(window, "setTimeout")
    panel = new PackageConfigPanel

    installedCallback = jasmine.createSpy("installed packages callback")
    panel.packageEventEmitter.on("installed-packages-loaded", installedCallback)
    waitsFor -> installedCallback.callCount > 0

  describe 'Installed tab', ->
    it "lists all installed packages with a link to enable or disable the package", ->
      p1View = panel.installed.find("[name='p1']").view()
      expect(p1View).toExist()
      expect(p1View.enableToggle.find('a').text()).toBe 'Enable'

      p2View = panel.installed.find("[name='p2']").view()
      expect(p2View).toExist()
      expect(p2View.enableToggle.find('a').text()).toBe 'Disable'

      p3View = panel.installed.find("[name='p3']").view()
      expect(p3View).toExist()
      expect(p3View.enableToggle.find('a').text()).toBe 'Enable'

    describe "when the core.disabledPackages array changes", ->
      it "updates the checkboxes for newly disabled / enabled packages", ->
        config.set('core.disabledPackages', ['p2'])
        p1View = panel.installed.find("[name='p1']").view()
        expect(p1View.enableToggle.find('a').text()).toBe 'Disable'

        p2View = panel.installed.find("[name='p2']").view()
        expect(p2View.enableToggle.find('a').text()).toBe 'Enable'

        p3View = panel.installed.find("[name='p3']").view()
        expect(p3View.enableToggle.find('a').text()).toBe 'Disable'

    describe "when the disable link is clicked", ->
      it "adds the package name to the disabled packages array", ->
        p2View = panel.installed.find("[name='p2']").view()
        p2View.enableToggle.find('a').click()
        expect(configObserver).toHaveBeenCalledWith(['p1', 'p3', 'p2'])

    describe "when the enable link is clicked", ->
      it "removes the package name from the disabled packages array", ->
        p3View = panel.installed.find("[name='p3']").view()
        p3View.enableToggle.find('a').click()
        expect(configObserver).toHaveBeenCalledWith(['p1'])

    describe "when Uninstall is clicked", ->
      it "removes the package from the tab", ->
        expect(panel.installed.find("[name='p1']")).toExist()
        p1View = panel.installed.find("[name='p1']").view()
        expect(p1View.defaultAction.text()).toBe 'Uninstall'
        p1View.defaultAction.click()
        expect(panel.installed.find("[name='p1']")).not.toExist()

  describe 'Available tab', ->
    it 'lists all available packages', ->
      panel.availableLink.click()
      panel.attachToDom()

      expect(panel.available.packagesArea.children('.panel').length).toBe 3
      p1View = panel.available.packagesArea.children('.panel:eq(0)').view()
      p2View = panel.available.packagesArea.children('.panel:eq(1)').view()
      p3View = panel.available.packagesArea.children('.panel:eq(2)').view()

      expect(p1View.name.text()).toBe 'p1'
      expect(p2View.name.text()).toBe 'p2'
      expect(p3View.name.text()).toBe 'p3'

      expect(p1View.version.text()).toBe '3.2.1'
      expect(p2View.version.text()).toBe '1.2.3'
      expect(p3View.version.text()).toBe '5.8.5'

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
      expect(p3View.homepage).toBeHidden()
      expect(p3View.issues).toBeHidden()
