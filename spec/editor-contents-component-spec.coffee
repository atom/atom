{React} = require 'reactionary'
EditorContentsComponent = require '../src/editor-contents-component'

describe "EditorComponent", ->
  container = null

  beforeEach ->
    container = document.querySelector('#jasmine-content')
    waitsForPromise -> atom.packages.activatePackage('language-javascript')

  it "renders the lines that are in view based on the relevant dimensions", ->
    editor = atom.project.openSync('sample.js')
    lineHeight = 20
    component = React.renderComponent(EditorContentsComponent({editor}), container)
    component.setState
      lineHeight: lineHeight
      height: 5 * lineHeight
      scrollTop: 3 * lineHeight
    console.log component.getDOMNode()
