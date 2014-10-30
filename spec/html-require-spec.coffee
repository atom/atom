describe "HTMLRequire", ->
  it "requires the html file and places it into a document fragment", ->
    html = require './fixtures/html-require.html'
    docFragment = html.getDocumentFragment()
    expect(docFragment.children.length).toBe 2
    expect(docFragment.querySelector('.one').tagName).toBe 'DIV'

  describe '.clone()', ->
    it "returns a cloned document fragment", ->
      html = require './fixtures/html-require.html'
      docFragment = html.clone()
      expect(docFragment.children.length).toBe 2
      expect(docFragment.querySelector('.one').tagName).toBe 'DIV'
