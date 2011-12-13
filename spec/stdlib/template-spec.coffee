Template = require 'template'

describe "Template", ->
  describe "toView", ->
    Foo = null

    beforeEach ->
      class Foo extends Template
        content: ->
          div ->
            h1 @title

    afterEach ->
      delete window.Foo

    it "builds a jquery object based on the content method and extends it with the viewProperties", ->
      view = Foo.buildView(title: "Hello World")
      expect(view.find('h1').text()).toEqual "Hello World"


