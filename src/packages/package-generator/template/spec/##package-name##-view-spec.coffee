##PackageName##View = require '##package-name##/lib/##package-name##-view'
RootView = require 'root-view'

# This spec is focused because it starts with an `f`. Remove the `f`
# to unfocus the spec.
#
# Press meta-alt-ctrl-s to run the specs
fdescribe "##PackageName##View", ->
  ##packageName## = null

  beforeEach ->
    window.rootView = new RootView
    ##packageName## = window.loadPackage('##packageName##', activateImmediately: true)

  describe "when the ##package-name##:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(rootView.find('.##package-name##')).not.toExist()
      rootView.trigger '##package-name##:toggle'
      expect(rootView.find('.##package-name##')).toExist()
      rootView.trigger '##package-name##:toggle'
      expect(rootView.find('.##package-name##')).not.toExist()
