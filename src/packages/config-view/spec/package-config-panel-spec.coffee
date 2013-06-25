PackageConfigPanel = require '../lib/package-config-panel'
packageManager = require '../lib/package-manager'
_ = require 'underscore'

describe "PackageConfigPanel", ->
  [panel, configObserver] = []

  beforeEach ->
    installedPackages = [
      {
        name: 'p1'
        version: '3.2.1'
      }
      {
        name: 'p2'
        version: '1.2.3'
      }
      {
        name: 'p3'
        version: '5.8.5'
      }
    ]

    availablePackages = [
      {
        name: 'p4'
        version: '3.2.1'
        homepage: 'http://p4.io'
      }
      {
        name: 'p5'
        version: '1.2.3'
        repository: url: 'http://github.com/atom/p5.git'
        bugs: url: 'http://github.com/atom/p5/issues'
      }
      {
        name: 'p6'
        version: '5.8.5'
      }
    ]

    spyOn(packageManager, 'getAvailable').andCallFake (callback) ->
      callback(null, availablePackages)
    spyOn(packageManager, 'uninstall').andCallFake (pack, callback) ->
      _.remove(installedPackages, pack)
      callback()
    spyOn(packageManager, 'install').andCallFake (pack, callback) ->
      installedPackages.push(pack)
      callback()

    spyOn(atom, 'getAvailablePackageMetadata').andReturn(installedPackages)
    spyOn(atom, 'resolvePackagePath').andCallFake (name) ->
      if _.contains(_.pluck(installedPackages, 'name'), name)
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
      p4View = panel.available.packagesArea.children('.panel:eq(0)').view()
      p5View = panel.available.packagesArea.children('.panel:eq(1)').view()
      p6View = panel.available.packagesArea.children('.panel:eq(2)').view()

      expect(p4View.name.text()).toBe 'p4'
      expect(p5View.name.text()).toBe 'p5'
      expect(p6View.name.text()).toBe 'p6'

      expect(p4View.version.text()).toBe '3.2.1'
      expect(p5View.version.text()).toBe '1.2.3'
      expect(p6View.version.text()).toBe '5.8.5'

      p4View.dropdownButton.click()
      expect(p4View.homepage).toBeVisible()
      expect(p4View.homepage.find('a').attr('href')).toBe 'http://p4.io'
      expect(p4View.issues).toBeHidden()

      p5View.dropdownButton.click()
      expect(p5View.homepage).toBeVisible()
      expect(p5View.homepage.find('a').attr('href')).toBe 'http://github.com/atom/p5'
      expect(p5View.issues).toBeVisible()
      expect(p5View.issues.find('a').attr('href')).toBe 'http://github.com/atom/p5/issues'

      p6View.dropdownButton.click()
      expect(p6View.homepage).toBeHidden()
      expect(p6View.issues).toBeHidden()

    describe "when Install is clicked", ->
      it "adds the package to the Installed tab", ->
        expect(panel.installed.find("[name='p4']")).not.toExist()
        expect(panel.available.find("[name='p4']")).toExist()
        p4View = panel.available.find("[name='p4']").view()
        expect(p4View.defaultAction.text()).toBe 'Install'
        p4View.defaultAction.click()
        expect(panel.installed.find("[name='p4']")).toExist()
        expect(p4View.defaultAction.text()).toBe 'Uninstall'
