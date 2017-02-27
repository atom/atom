/** @babel */

import {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise} from './async-spec-helpers'
import Grim from 'grim'
import TextEditor from '../src/text-editor'
import TextEditorElement from '../src/text-editor-element'
import _, {extend, flatten, last, toArray} from 'underscore-plus'

const NBSP = String.fromCharCode(160)
const TILE_SIZE = 3

describe('TextEditorComponent', function () {
  let charWidth, component, componentNode, contentNode, editor,
      horizontalScrollbarNode, lineHeightInPixels, tileHeightInPixels,
      verticalScrollbarNode, wrapperNode, animationFrameRequests

  function runAnimationFrames (runFollowupFrames) {
    if (runFollowupFrames) {
      let fn
      while (fn = animationFrameRequests.shift()) fn()
    } else {
      const requests = animationFrameRequests.slice()
      animationFrameRequests = []
      for (let fn of requests) fn()
    }
  }

  beforeEach(async function () {
    animationFrameRequests = []
    spyOn(window, 'requestAnimationFrame').andCallFake(function (fn) { animationFrameRequests.push(fn) })
    jasmine.useMockClock()

    await atom.packages.activatePackage('language-javascript')
    editor = await atom.workspace.open('sample.js')
    editor.update({autoHeight: true})

    contentNode = document.querySelector('#jasmine-content')
    contentNode.style.width = '1000px'

    wrapperNode = new TextEditorElement()
    wrapperNode.tileSize = TILE_SIZE
    wrapperNode.initialize(editor, atom)
    wrapperNode.setUpdatedSynchronously(false)
    jasmine.attachToDOM(wrapperNode)

    component = wrapperNode.component
    component.setFontFamily('monospace')
    component.setLineHeight(1.3)
    component.setFontSize(20)

    lineHeightInPixels = editor.getLineHeightInPixels()
    tileHeightInPixels = TILE_SIZE * lineHeightInPixels
    charWidth = editor.getDefaultCharWidth()

    componentNode = component.getDomNode()
    verticalScrollbarNode = componentNode.querySelector('.vertical-scrollbar')
    horizontalScrollbarNode = componentNode.querySelector('.horizontal-scrollbar')

    component.measureDimensions()
    advanceClock(atom.views.minimumPollInterval)
    runAnimationFrames(true)
  })

  afterEach(function () {
    contentNode.style.width = ''
  })

  describe('async updates', function () {
    it('handles corrupted state gracefully', function () {
      editor.insertNewline()
      component.presenter.startRow = -1
      component.presenter.endRow = 9999
      runAnimationFrames() // assert an update does occur
    })

    it('does not update when an animation frame was requested but the component got destroyed before its delivery', function () {
      editor.setText('You should not see this update.')
      component.destroy()

      runAnimationFrames()

      expect(component.lineNodeForScreenRow(0).textContent).not.toBe('You should not see this update.')
    })
  })

  describe('line rendering', function () {
    function expectTileContainsRow (tileNode, screenRow, {top}) {
      let lineNode = tileNode.querySelector('[data-screen-row="' + screenRow + '"]')
      let text = editor.lineTextForScreenRow(screenRow)
      expect(lineNode.offsetTop).toBe(top)
      if (text === '') {
        expect(lineNode.textContent).toBe(' ')
      } else {
        expect(lineNode.textContent).toBe(text)
      }
    }

    it('gives the lines container the same height as the wrapper node', function () {
      let linesNode = componentNode.querySelector('.lines')
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(linesNode.getBoundingClientRect().height).toBe(6.5 * lineHeightInPixels)
      wrapperNode.style.height = 3.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      expect(linesNode.getBoundingClientRect().height).toBe(3.5 * lineHeightInPixels)
    })

    it('renders higher tiles in front of lower ones', function () {
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      let tilesNodes = component.tileNodesForLines()
      expect(tilesNodes[0].style.zIndex).toBe('2')
      expect(tilesNodes[1].style.zIndex).toBe('1')
      expect(tilesNodes[2].style.zIndex).toBe('0')
      verticalScrollbarNode.scrollTop = 1 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      tilesNodes = component.tileNodesForLines()
      expect(tilesNodes[0].style.zIndex).toBe('3')
      expect(tilesNodes[1].style.zIndex).toBe('2')
      expect(tilesNodes[2].style.zIndex).toBe('1')
      expect(tilesNodes[3].style.zIndex).toBe('0')
    })

    it('renders the currently-visible lines in a tiled fashion', function () {
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      let tilesNodes = component.tileNodesForLines()
      expect(tilesNodes.length).toBe(3)

      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, 0px, 0px)')
      expect(tilesNodes[0].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[0], 0, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 1, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 2, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels) + 'px, 0px)')
      expect(tilesNodes[1].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[1], 3, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 4, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 5, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[2].style['-webkit-transform']).toBe('translate3d(0px, ' + (2 * tileHeightInPixels) + 'px, 0px)')
      expect(tilesNodes[2].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[2], 6, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 7, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 8, {
        top: 2 * lineHeightInPixels
      })

      expect(component.lineNodeForScreenRow(9)).toBeUndefined()

      verticalScrollbarNode.scrollTop = TILE_SIZE * lineHeightInPixels + 5
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      tilesNodes = component.tileNodesForLines()
      expect(component.lineNodeForScreenRow(2)).toBeUndefined()
      expect(tilesNodes.length).toBe(3)

      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, ' + (0 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[0].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[0], 3, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 4, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 5, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[1].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[1], 6, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 7, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 8, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[2].style['-webkit-transform']).toBe('translate3d(0px, ' + (2 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[2].querySelectorAll('.line').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[2], 9, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 10, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 11, {
        top: 2 * lineHeightInPixels
      })
    })

    it('updates the top position of subsequent tiles when lines are inserted or removed', function () {
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      editor.getBuffer().deleteRows(0, 1)

      runAnimationFrames()

      let tilesNodes = component.tileNodesForLines()
      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, 0px, 0px)')
      expectTileContainsRow(tilesNodes[0], 0, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 1, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 2, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels) + 'px, 0px)')
      expectTileContainsRow(tilesNodes[1], 3, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 4, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 5, {
        top: 2 * lineHeightInPixels
      })

      editor.getBuffer().insert([0, 0], '\n\n')

      runAnimationFrames()

      tilesNodes = component.tileNodesForLines()
      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, 0px, 0px)')
      expectTileContainsRow(tilesNodes[0], 0, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 1, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[0], 2, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels) + 'px, 0px)')
      expectTileContainsRow(tilesNodes[1], 3, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 4, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[1], 5, {
        top: 2 * lineHeightInPixels
      })

      expect(tilesNodes[2].style['-webkit-transform']).toBe('translate3d(0px, ' + (2 * tileHeightInPixels) + 'px, 0px)')
      expectTileContainsRow(tilesNodes[2], 6, {
        top: 0 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 7, {
        top: 1 * lineHeightInPixels
      })
      expectTileContainsRow(tilesNodes[2], 8, {
        top: 2 * lineHeightInPixels
      })
    })

    it('updates the lines when lines are inserted or removed above the rendered row range', function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      verticalScrollbarNode.scrollTop = 5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      let buffer = editor.getBuffer()
      buffer.insert([0, 0], '\n\n')

      runAnimationFrames()

      expect(component.lineNodeForScreenRow(3).textContent).toBe(editor.lineTextForScreenRow(3))
      buffer.delete([[0, 0], [3, 0]])

      runAnimationFrames()

      expect(component.lineNodeForScreenRow(3).textContent).toBe(editor.lineTextForScreenRow(3))
    })

    it('updates the top position of lines when the line height changes', function () {
      let initialLineHeightInPixels = editor.getLineHeightInPixels()

      component.setLineHeight(2)

      runAnimationFrames()

      let newLineHeightInPixels = editor.getLineHeightInPixels()
      expect(newLineHeightInPixels).not.toBe(initialLineHeightInPixels)
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe(1 * newLineHeightInPixels)
    })

    it('updates the top position of lines when the font size changes', function () {
      let initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setFontSize(10)

      runAnimationFrames()

      let newLineHeightInPixels = editor.getLineHeightInPixels()
      expect(newLineHeightInPixels).not.toBe(initialLineHeightInPixels)
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe(1 * newLineHeightInPixels)
    })

    it('renders the .lines div at the full height of the editor if there are not enough lines to scroll vertically', function () {
      editor.setText('')
      wrapperNode.style.height = '300px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()
      let linesNode = componentNode.querySelector('.lines')
      expect(linesNode.offsetHeight).toBe(300)
    })

    it('assigns the width of each line so it extends across the full width of the editor', function () {
      let gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      let scrollViewNode = componentNode.querySelector('.scroll-view')
      let lineNodes = Array.from(componentNode.querySelectorAll('.line'))

      componentNode.style.width = gutterWidth + (30 * charWidth) + 'px'
      component.measureDimensions()

      runAnimationFrames()

      expect(wrapperNode.getScrollWidth()).toBeGreaterThan(scrollViewNode.offsetWidth)
      let editorFullWidth = wrapperNode.getScrollWidth() + wrapperNode.getVerticalScrollbarWidth()
      for (let lineNode of lineNodes) {
        expect(lineNode.getBoundingClientRect().width).toBe(editorFullWidth)
      }

      componentNode.style.width = gutterWidth + wrapperNode.getScrollWidth() + 100 + 'px'
      component.measureDimensions()

      runAnimationFrames()

      let scrollViewWidth = scrollViewNode.offsetWidth
      for (let lineNode of lineNodes) {
        expect(lineNode.getBoundingClientRect().width).toBe(scrollViewWidth)
      }
    })

    it('renders a placeholder space on empty lines when no line-ending character is defined', function () {
      editor.update({showInvisibles: false})
      expect(component.lineNodeForScreenRow(10).textContent).toBe(' ')
    })

    it('gives the lines and tiles divs the same background color as the editor to improve GPU performance', async function () {
      let linesNode = componentNode.querySelector('.lines')
      let backgroundColor = getComputedStyle(wrapperNode).backgroundColor

      expect(linesNode.style.backgroundColor).toBe(backgroundColor)
      for (let tileNode of component.tileNodesForLines()) {
        expect(tileNode.style.backgroundColor).toBe(backgroundColor)
      }

      wrapperNode.style.backgroundColor = 'rgb(255, 0, 0)'
      // Polling should happen automatically in a mutation observer but its async
      // and everything is mocked to be sync
      atom.views.performDocumentPoll()
      runAnimationFrames(true)

      expect(linesNode.style.backgroundColor).toBe('rgb(255, 0, 0)')
      for (let tileNode of component.tileNodesForLines()) {
        expect(tileNode.style.backgroundColor).toBe('rgb(255, 0, 0)')
      }
    })

    it('applies .leading-whitespace for lines with leading spaces and/or tabs', function () {
      editor.setText(' a')

      runAnimationFrames()

      let leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(false)

      editor.setText('\ta')
      runAnimationFrames()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(false)
    })

    it('applies .trailing-whitespace for lines with trailing spaces and/or tabs', function () {
      editor.setText(' ')
      runAnimationFrames()

      let leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(false)

      editor.setText('\t')
      runAnimationFrames()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(false)
      editor.setText('a ')
      runAnimationFrames()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(false)
      editor.setText('a\t')
      runAnimationFrames()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe(true)
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe(false)
    })

    it('keeps rebuilding lines when continuous reflow is on', function () {
      wrapperNode.setContinuousReflow(true)
      let oldLineNode = componentNode.querySelectorAll('.line')[1]

      while (true) {
        runAnimationFrames()
        if (componentNode.querySelectorAll('.line')[1] !== oldLineNode) break
      }
    })

    describe('when showInvisibles is enabled', function () {
      const invisibles = {
        eol: 'E',
        space: 'S',
        tab: 'T',
        cr: 'C'
      }

      beforeEach(function () {
        editor.update({
          showInvisibles: true,
          invisibles: invisibles
        })
        runAnimationFrames()
      })

      it('re-renders the lines when the showInvisibles config option changes', function () {
        editor.setText(' a line with tabs\tand spaces \n')
        runAnimationFrames()

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + invisibles.space + 'a line with tabs' + invisibles.tab + 'and spaces' + invisibles.space + invisibles.eol)

        editor.update({showInvisibles: false})
        runAnimationFrames()

        expect(component.lineNodeForScreenRow(0).textContent).toBe(' a line with tabs and spaces ')

        editor.update({showInvisibles: true})
        runAnimationFrames()

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + invisibles.space + 'a line with tabs' + invisibles.tab + 'and spaces' + invisibles.space + invisibles.eol)
      })

      it('displays leading/trailing spaces, tabs, and newlines as visible characters', function () {
        editor.setText(' a line with tabs\tand spaces \n')

        runAnimationFrames()

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + invisibles.space + 'a line with tabs' + invisibles.tab + 'and spaces' + invisibles.space + invisibles.eol)

        let leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('invisible-character')).toBe(true)
        expect(leafNodes[leafNodes.length - 1].classList.contains('invisible-character')).toBe(true)
      })

      it('displays newlines as their own token outside of the other tokens\' scopeDescriptor', function () {
        editor.setText('let\n')
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(0).innerHTML).toBe('<span class="syntax--source syntax--js"><span class="syntax--storage syntax--type syntax--var syntax--js">let</span><span class="invisible-character eol">' + invisibles.eol + '</span></span>')
      })

      it('displays trailing carriage returns using a visible, non-empty value', function () {
        editor.setText('a line that ends with a carriage return\r\n')
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(0).textContent).toBe('a line that ends with a carriage return' + invisibles.cr + invisibles.eol)
      })

      it('renders invisible line-ending characters on empty lines', function () {
        expect(component.lineNodeForScreenRow(10).textContent).toBe(invisibles.eol)
      })

      it('renders a placeholder space on empty lines when the line-ending character is an empty string', function () {
        editor.update({invisibles: {eol: ''}})
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).textContent).toBe(' ')
      })

      it('renders an placeholder space on empty lines when the line-ending character is false', function () {
        editor.update({invisibles: {eol: false}})
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).textContent).toBe(' ')
      })

      it('interleaves invisible line-ending characters with indent guides on empty lines', function () {
        editor.update({showIndentGuide: true})

        runAnimationFrames()

        editor.setTabLength(2)
        editor.setTextInBufferRange([[10, 0], [11, 0]], '\r\n', {
          normalizeLineEndings: false
        })
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe('<span class="syntax--source syntax--js"><span class="invisible-character eol indent-guide">CE</span></span>')

        editor.setTabLength(3)
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe('<span class="syntax--source syntax--js"><span class="invisible-character eol indent-guide">CE</span></span>')

        editor.setTabLength(1)
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe('<span class="syntax--source syntax--js"><span class="invisible-character eol indent-guide">CE</span></span>')

        editor.setTextInBufferRange([[9, 0], [9, Infinity]], ' ')
        editor.setTextInBufferRange([[11, 0], [11, Infinity]], ' ')
        runAnimationFrames()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe('<span class="syntax--source syntax--js"><span class="invisible-character eol indent-guide">CE</span></span>')
      })

      describe('when soft wrapping is enabled', function () {
        beforeEach(function () {
          editor.setText('a line that wraps \n')
          editor.setSoftWrapped(true)
          runAnimationFrames()

          componentNode.style.width = 17 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
          component.measureDimensions()
          runAnimationFrames()
        })

        it('does not show end of line invisibles at the end of wrapped lines', function () {
          expect(component.lineNodeForScreenRow(0).textContent).toBe('a line ')
          expect(component.lineNodeForScreenRow(1).textContent).toBe('that wraps' + invisibles.space + invisibles.eol)
        })
      })
    })

    describe('when indent guides are enabled', function () {
      beforeEach(function () {
        editor.update({showIndentGuide: true})
        runAnimationFrames()
      })

      it('adds an "indent-guide" class to spans comprising the leading whitespace', function () {
        let line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe('  ')
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe(false)

        let line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes[0].textContent).toBe('  ')
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[1].textContent).toBe('  ')
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe(false)
      })

      it('renders leading whitespace spans with the "indent-guide" class for empty lines', function () {
        editor.getBuffer().insert([1, Infinity], '\n')
        runAnimationFrames()

        let line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes.length).toBe(2)
        expect(line2LeafNodes[0].textContent).toBe('  ')
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[1].textContent).toBe('  ')
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe(true)
      })

      it('renders indent guides correctly on lines containing only whitespace', function () {
        editor.getBuffer().insert([1, Infinity], '\n      ')
        runAnimationFrames()

        let line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes.length).toBe(3)
        expect(line2LeafNodes[0].textContent).toBe('  ')
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[1].textContent).toBe('  ')
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[2].textContent).toBe('  ')
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe(true)
      })

      it('renders indent guides correctly on lines containing only whitespace when invisibles are enabled', function () {
        editor.update({
          showInvisibles: true,
          invisibles: {
            space: '-',
            eol: 'x'
          }
        })
        editor.getBuffer().insert([1, Infinity], '\n      ')

        runAnimationFrames()

        let line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes.length).toBe(4)
        expect(line2LeafNodes[0].textContent).toBe('--')
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[1].textContent).toBe('--')
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[2].textContent).toBe('--')
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe(true)
        expect(line2LeafNodes[3].textContent).toBe('x')
      })

      it('does not render indent guides in trailing whitespace for lines containing non whitespace characters', function () {
        editor.getBuffer().setText('  hi  ')

        runAnimationFrames()

        let line0LeafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(line0LeafNodes[0].textContent).toBe('  ')
        expect(line0LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line0LeafNodes[1].textContent).toBe('  ')
        expect(line0LeafNodes[1].classList.contains('indent-guide')).toBe(false)
      })

      it('updates the indent guides on empty lines preceding an indentation change', function () {
        editor.getBuffer().insert([12, 0], '\n')
        runAnimationFrames()

        editor.getBuffer().insert([13, 0], '    ')
        runAnimationFrames()

        let line12LeafNodes = getLeafNodes(component.lineNodeForScreenRow(12))
        expect(line12LeafNodes[0].textContent).toBe('  ')
        expect(line12LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line12LeafNodes[1].textContent).toBe('  ')
        expect(line12LeafNodes[1].classList.contains('indent-guide')).toBe(true)
      })

      it('updates the indent guides on empty lines following an indentation change', function () {
        editor.getBuffer().insert([12, 2], '\n')

        runAnimationFrames()

        editor.getBuffer().insert([12, 0], '    ')
        runAnimationFrames()

        let line13LeafNodes = getLeafNodes(component.lineNodeForScreenRow(13))
        expect(line13LeafNodes[0].textContent).toBe('  ')
        expect(line13LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line13LeafNodes[1].textContent).toBe('  ')
        expect(line13LeafNodes[1].classList.contains('indent-guide')).toBe(true)
      })
    })

    describe('when indent guides are disabled', function () {
      beforeEach(function () {
        expect(atom.config.get('editor.showIndentGuide')).toBe(false)
      })

      it('does not render indent guides on lines containing only whitespace', function () {
        editor.getBuffer().insert([1, Infinity], '\n      ')

        runAnimationFrames()

        let line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes.length).toBe(1)
        expect(line2LeafNodes[0].textContent).toBe('      ')
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe(false)
      })
    })

    describe('when the buffer contains null bytes', function () {
      it('excludes the null byte from character measurement', function () {
        editor.setText('a\0b')
        runAnimationFrames()
        expect(wrapperNode.pixelPositionForScreenPosition([0, Infinity]).left).toEqual(2 * charWidth)
      })
    })

    describe('when there is a fold', function () {
      it('renders a fold marker on the folded line', function () {
        let foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()
        editor.foldBufferRow(4)

        runAnimationFrames()

        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeTruthy()
        editor.unfoldBufferRow(4)

        runAnimationFrames()

        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()
      })
    })
  })

  describe('gutter rendering', function () {
    function expectTileContainsRow (tileNode, screenRow, {top, text}) {
      let lineNode = tileNode.querySelector('[data-screen-row="' + screenRow + '"]')
      expect(lineNode.offsetTop).toBe(top)
      expect(lineNode.textContent).toBe(text)
    }

    it('renders higher tiles in front of lower ones', function () {
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames(true)

      let tilesNodes = component.tileNodesForLineNumbers()
      expect(tilesNodes[0].style.zIndex).toBe('2')
      expect(tilesNodes[1].style.zIndex).toBe('1')
      expect(tilesNodes[2].style.zIndex).toBe('0')
      verticalScrollbarNode.scrollTop = 1 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      tilesNodes = component.tileNodesForLineNumbers()
      expect(tilesNodes[0].style.zIndex).toBe('3')
      expect(tilesNodes[1].style.zIndex).toBe('2')
      expect(tilesNodes[2].style.zIndex).toBe('1')
      expect(tilesNodes[3].style.zIndex).toBe('0')
    })

    it('gives the line numbers container the same height as the wrapper node', function () {
      let linesNode = componentNode.querySelector('.line-numbers')
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      expect(linesNode.getBoundingClientRect().height).toBe(6.5 * lineHeightInPixels)
      wrapperNode.style.height = 3.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      expect(linesNode.getBoundingClientRect().height).toBe(3.5 * lineHeightInPixels)
    })

    it('renders the currently-visible line numbers in a tiled fashion', function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      let tilesNodes = component.tileNodesForLineNumbers()
      expect(tilesNodes.length).toBe(3)

      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, 0px, 0px)')
      expect(tilesNodes[0].querySelectorAll('.line-number').length).toBe(3)
      expectTileContainsRow(tilesNodes[0], 0, {
        top: lineHeightInPixels * 0,
        text: '' + NBSP + '1'
      })
      expectTileContainsRow(tilesNodes[0], 1, {
        top: lineHeightInPixels * 1,
        text: '' + NBSP + '2'
      })
      expectTileContainsRow(tilesNodes[0], 2, {
        top: lineHeightInPixels * 2,
        text: '' + NBSP + '3'
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels) + 'px, 0px)')
      expect(tilesNodes[1].querySelectorAll('.line-number').length).toBe(3)
      expectTileContainsRow(tilesNodes[1], 3, {
        top: lineHeightInPixels * 0,
        text: '' + NBSP + '4'
      })
      expectTileContainsRow(tilesNodes[1], 4, {
        top: lineHeightInPixels * 1,
        text: '' + NBSP + '5'
      })
      expectTileContainsRow(tilesNodes[1], 5, {
        top: lineHeightInPixels * 2,
        text: '' + NBSP + '6'
      })

      expect(tilesNodes[2].style['-webkit-transform']).toBe('translate3d(0px, ' + (2 * tileHeightInPixels) + 'px, 0px)')
      expect(tilesNodes[2].querySelectorAll('.line-number').length).toBe(3)
      expectTileContainsRow(tilesNodes[2], 6, {
        top: lineHeightInPixels * 0,
        text: '' + NBSP + '7'
      })
      expectTileContainsRow(tilesNodes[2], 7, {
        top: lineHeightInPixels * 1,
        text: '' + NBSP + '8'
      })
      expectTileContainsRow(tilesNodes[2], 8, {
        top: lineHeightInPixels * 2,
        text: '' + NBSP + '9'
      })
      verticalScrollbarNode.scrollTop = TILE_SIZE * lineHeightInPixels + 5
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      tilesNodes = component.tileNodesForLineNumbers()
      expect(component.lineNumberNodeForScreenRow(2)).toBeUndefined()
      expect(tilesNodes.length).toBe(3)

      expect(tilesNodes[0].style['-webkit-transform']).toBe('translate3d(0px, ' + (0 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[0].querySelectorAll('.line-number').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[0], 3, {
        top: lineHeightInPixels * 0,
        text: '' + NBSP + '4'
      })
      expectTileContainsRow(tilesNodes[0], 4, {
        top: lineHeightInPixels * 1,
        text: '' + NBSP + '5'
      })
      expectTileContainsRow(tilesNodes[0], 5, {
        top: lineHeightInPixels * 2,
        text: '' + NBSP + '6'
      })

      expect(tilesNodes[1].style['-webkit-transform']).toBe('translate3d(0px, ' + (1 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[1].querySelectorAll('.line-number').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[1], 6, {
        top: 0 * lineHeightInPixels,
        text: '' + NBSP + '7'
      })
      expectTileContainsRow(tilesNodes[1], 7, {
        top: 1 * lineHeightInPixels,
        text: '' + NBSP + '8'
      })
      expectTileContainsRow(tilesNodes[1], 8, {
        top: 2 * lineHeightInPixels,
        text: '' + NBSP + '9'
      })

      expect(tilesNodes[2].style['-webkit-transform']).toBe('translate3d(0px, ' + (2 * tileHeightInPixels - 5) + 'px, 0px)')
      expect(tilesNodes[2].querySelectorAll('.line-number').length).toBe(TILE_SIZE)
      expectTileContainsRow(tilesNodes[2], 9, {
        top: 0 * lineHeightInPixels,
        text: '10'
      })
      expectTileContainsRow(tilesNodes[2], 10, {
        top: 1 * lineHeightInPixels,
        text: '11'
      })
      expectTileContainsRow(tilesNodes[2], 11, {
        top: 2 * lineHeightInPixels,
        text: '12'
      })
    })

    it('updates the translation of subsequent line numbers when lines are inserted or removed', function () {
      editor.getBuffer().insert([0, 0], '\n\n')
      runAnimationFrames()

      let lineNumberNodes = componentNode.querySelectorAll('.line-number')
      expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe(0 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe(1 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe(2 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe(0 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe(1 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(5).offsetTop).toBe(2 * lineHeightInPixels)
      editor.getBuffer().insert([0, 0], '\n\n')

      runAnimationFrames()

      expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe(0 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe(1 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe(2 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe(0 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe(1 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(5).offsetTop).toBe(2 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(6).offsetTop).toBe(0 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(7).offsetTop).toBe(1 * lineHeightInPixels)
      expect(component.lineNumberNodeForScreenRow(8).offsetTop).toBe(2 * lineHeightInPixels)
    })

    it('renders • characters for soft-wrapped lines', function () {
      editor.setSoftWrapped(true)
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 30 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()

      runAnimationFrames()

      expect(componentNode.querySelectorAll('.line-number').length).toBe(9 + 1)
      expect(component.lineNumberNodeForScreenRow(0).textContent).toBe('' + NBSP + '1')
      expect(component.lineNumberNodeForScreenRow(1).textContent).toBe('' + NBSP + '•')
      expect(component.lineNumberNodeForScreenRow(2).textContent).toBe('' + NBSP + '2')
      expect(component.lineNumberNodeForScreenRow(3).textContent).toBe('' + NBSP + '•')
      expect(component.lineNumberNodeForScreenRow(4).textContent).toBe('' + NBSP + '3')
      expect(component.lineNumberNodeForScreenRow(5).textContent).toBe('' + NBSP + '•')
      expect(component.lineNumberNodeForScreenRow(6).textContent).toBe('' + NBSP + '4')
      expect(component.lineNumberNodeForScreenRow(7).textContent).toBe('' + NBSP + '•')
      expect(component.lineNumberNodeForScreenRow(8).textContent).toBe('' + NBSP + '•')
    })

    it('pads line numbers to be right-justified based on the maximum number of line number digits', function () {
      const input = [];
      for (let i = 1; i <= 100; ++i) {
        input.push(i);
      }
      editor.getBuffer().setText(input.join('\n'))
      runAnimationFrames()

      for (let screenRow = 0; screenRow <= 8; ++screenRow) {
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe('' + NBSP + NBSP + (screenRow + 1))
      }
      expect(component.lineNumberNodeForScreenRow(99).textContent).toBe('100')
      let gutterNode = componentNode.querySelector('.gutter')
      let initialGutterWidth = gutterNode.offsetWidth
      editor.getBuffer().delete([[1, 0], [2, 0]])

      runAnimationFrames()

      for (let screenRow = 0; screenRow <= 8; ++screenRow) {
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe('' + NBSP + (screenRow + 1))
      }
      expect(gutterNode.offsetWidth).toBeLessThan(initialGutterWidth)
      editor.getBuffer().insert([0, 0], '\n\n')

      runAnimationFrames()

      for (let screenRow = 0; screenRow <= 8; ++screenRow) {
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe('' + NBSP + NBSP + (screenRow + 1))
      }
      expect(component.lineNumberNodeForScreenRow(99).textContent).toBe('100')
      expect(gutterNode.offsetWidth).toBe(initialGutterWidth)
    })

    it('renders the .line-numbers div at the full height of the editor even if it\'s taller than its content', function () {
      wrapperNode.style.height = componentNode.offsetHeight + 100 + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()
      expect(componentNode.querySelector('.line-numbers').offsetHeight).toBe(componentNode.offsetHeight)
    })

    it('applies the background color of the gutter or the editor to the line numbers to improve GPU performance', function () {
      let gutterNode = componentNode.querySelector('.gutter')
      let lineNumbersNode = gutterNode.querySelector('.line-numbers')
      let backgroundColor = getComputedStyle(wrapperNode).backgroundColor
      expect(lineNumbersNode.style.backgroundColor).toBe(backgroundColor)
      for (let tileNode of component.tileNodesForLineNumbers()) {
        expect(tileNode.style.backgroundColor).toBe(backgroundColor)
      }

      gutterNode.style.backgroundColor = 'rgb(255, 0, 0)'
      atom.views.performDocumentPoll()
      runAnimationFrames()

      expect(lineNumbersNode.style.backgroundColor).toBe('rgb(255, 0, 0)')
      for (let tileNode of component.tileNodesForLineNumbers()) {
        expect(tileNode.style.backgroundColor).toBe('rgb(255, 0, 0)')
      }
    })

    it('hides or shows the gutter based on the "::isLineNumberGutterVisible" property on the model and the global "editor.showLineNumbers" config setting', function () {
      expect(component.gutterContainerComponent.getLineNumberGutterComponent() != null).toBe(true)
      editor.setLineNumberGutterVisible(false)
      runAnimationFrames()

      expect(componentNode.querySelector('.gutter').style.display).toBe('none')
      editor.update({showLineNumbers: false})
      runAnimationFrames()

      expect(componentNode.querySelector('.gutter').style.display).toBe('none')
      editor.setLineNumberGutterVisible(true)
      runAnimationFrames()

      expect(componentNode.querySelector('.gutter').style.display).toBe('none')
      editor.update({showLineNumbers: true})
      runAnimationFrames()

      expect(componentNode.querySelector('.gutter').style.display).toBe('')
      expect(component.lineNumberNodeForScreenRow(3) != null).toBe(true)
    })

    it('keeps rebuilding line numbers when continuous reflow is on', function () {
      wrapperNode.setContinuousReflow(true)
      let oldLineNode = componentNode.querySelectorAll('.line-number')[1]

      while (true) {
        runAnimationFrames()
        if (componentNode.querySelectorAll('.line-number')[1] !== oldLineNode) break
      }
    })

    describe('fold decorations', function () {
      describe('rendering fold decorations', function () {
        it('adds the foldable class to line numbers when the line is foldable', function () {
          expect(lineNumberHasClass(0, 'foldable')).toBe(true)
          expect(lineNumberHasClass(1, 'foldable')).toBe(true)
          expect(lineNumberHasClass(2, 'foldable')).toBe(false)
          expect(lineNumberHasClass(3, 'foldable')).toBe(false)
          expect(lineNumberHasClass(4, 'foldable')).toBe(true)
          expect(lineNumberHasClass(5, 'foldable')).toBe(false)
        })

        it('updates the foldable class on the correct line numbers when the foldable positions change', function () {
          editor.getBuffer().insert([0, 0], '\n')
          runAnimationFrames()

          expect(lineNumberHasClass(0, 'foldable')).toBe(false)
          expect(lineNumberHasClass(1, 'foldable')).toBe(true)
          expect(lineNumberHasClass(2, 'foldable')).toBe(true)
          expect(lineNumberHasClass(3, 'foldable')).toBe(false)
          expect(lineNumberHasClass(4, 'foldable')).toBe(false)
          expect(lineNumberHasClass(5, 'foldable')).toBe(true)
          expect(lineNumberHasClass(6, 'foldable')).toBe(false)
        })

        it('updates the foldable class on a line number that becomes foldable', function () {
          expect(lineNumberHasClass(11, 'foldable')).toBe(false)
          editor.getBuffer().insert([11, 44], '\n    fold me')
          runAnimationFrames()
          expect(lineNumberHasClass(11, 'foldable')).toBe(true)
          editor.undo()
          runAnimationFrames()
          expect(lineNumberHasClass(11, 'foldable')).toBe(false)
        })

        it('adds, updates and removes the folded class on the correct line number componentNodes', function () {
          editor.foldBufferRow(4)
          runAnimationFrames()

          expect(lineNumberHasClass(4, 'folded')).toBe(true)

          editor.getBuffer().insert([0, 0], '\n')
          runAnimationFrames()

          expect(lineNumberHasClass(4, 'folded')).toBe(false)
          expect(lineNumberHasClass(5, 'folded')).toBe(true)

          editor.unfoldBufferRow(5)
          runAnimationFrames()

          expect(lineNumberHasClass(5, 'folded')).toBe(false)
        })

        describe('when soft wrapping is enabled', function () {
          beforeEach(function () {
            editor.setSoftWrapped(true)
            runAnimationFrames()
            componentNode.style.width = 20 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
            component.measureDimensions()
            runAnimationFrames()
          })

          it('does not add the foldable class for soft-wrapped lines', function () {
            expect(lineNumberHasClass(0, 'foldable')).toBe(true)
            expect(lineNumberHasClass(1, 'foldable')).toBe(false)
          })

          it('does not add the folded class for soft-wrapped lines that contain a fold', function () {
            editor.foldBufferRange([[3, 19], [3, 21]])
            runAnimationFrames()

            expect(lineNumberHasClass(11, 'folded')).toBe(true)
            expect(lineNumberHasClass(12, 'folded')).toBe(false)
          })
        })
      })

      describe('mouse interactions with fold indicators', function () {
        let gutterNode

        function buildClickEvent (target) {
          return buildMouseEvent('click', {
            target: target
          })
        }

        beforeEach(function () {
          gutterNode = componentNode.querySelector('.gutter')
        })

        describe('when the component is destroyed', function () {
          it('stops listening for folding events', function () {
            let lineNumber, target
            component.destroy()
            lineNumber = component.lineNumberNodeForScreenRow(1)
            target = lineNumber.querySelector('.icon-right')
            target.dispatchEvent(buildClickEvent(target))
          })
        })

        it('folds and unfolds the block represented by the fold indicator when clicked', function () {
          expect(lineNumberHasClass(1, 'folded')).toBe(false)

          let lineNumber = component.lineNumberNodeForScreenRow(1)
          let target = lineNumber.querySelector('.icon-right')

          target.dispatchEvent(buildClickEvent(target))

          runAnimationFrames()

          expect(lineNumberHasClass(1, 'folded')).toBe(true)
          lineNumber = component.lineNumberNodeForScreenRow(1)
          target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))

          runAnimationFrames()

          expect(lineNumberHasClass(1, 'folded')).toBe(false)
        })

        it('unfolds all the free-form folds intersecting the buffer row when clicked', function () {
          expect(lineNumberHasClass(3, 'foldable')).toBe(false)

          editor.foldBufferRange([[3, 4], [5, 4]])
          editor.foldBufferRange([[5, 5], [8, 10]])
          runAnimationFrames()
          expect(lineNumberHasClass(3, 'folded')).toBe(true)
          expect(lineNumberHasClass(5, 'folded')).toBe(false)

          let lineNumber = component.lineNumberNodeForScreenRow(3)
          let target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))
          runAnimationFrames()
          expect(lineNumberHasClass(3, 'folded')).toBe(false)
          expect(lineNumberHasClass(5, 'folded')).toBe(true)

          editor.setSoftWrapped(true)
          componentNode.style.width = 20 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
          component.measureDimensions()
          runAnimationFrames()
          editor.foldBufferRange([[3, 19], [3, 21]]) // fold starting on a soft-wrapped portion of the line
          runAnimationFrames()
          expect(lineNumberHasClass(11, 'folded')).toBe(true)

          lineNumber = component.lineNumberNodeForScreenRow(11)
          target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))
          runAnimationFrames()
          expect(lineNumberHasClass(11, 'folded')).toBe(false)
        })

        it('does not fold when the line number componentNode is clicked', function () {
          let lineNumber = component.lineNumberNodeForScreenRow(1)
          lineNumber.dispatchEvent(buildClickEvent(lineNumber))
          waits(100)
          runs(function () {
            expect(lineNumberHasClass(1, 'folded')).toBe(false)
          })
        })
      })
    })
  })

  describe('cursor rendering', function () {
    it('renders the currently visible cursors', function () {
      let cursor1 = editor.getLastCursor()
      cursor1.setScreenPosition([0, 5], {
        autoscroll: false
      })
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      let cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(1)
      expect(cursorNodes[0].offsetHeight).toBe(lineHeightInPixels)
      expect(cursorNodes[0].offsetWidth).toBeCloseTo(charWidth, 0)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(5 * charWidth)) + 'px, ' + (0 * lineHeightInPixels) + 'px)')
      let cursor2 = editor.addCursorAtScreenPosition([8, 11], {
        autoscroll: false
      })
      let cursor3 = editor.addCursorAtScreenPosition([4, 10], {
        autoscroll: false
      })
      runAnimationFrames()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(2)
      expect(cursorNodes[0].offsetTop).toBe(0)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(5 * charWidth)) + 'px, ' + (0 * lineHeightInPixels) + 'px)')
      expect(cursorNodes[1].style['-webkit-transform']).toBe('translate(' + (Math.round(10 * charWidth)) + 'px, ' + (4 * lineHeightInPixels) + 'px)')
      verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      horizontalScrollbarNode.scrollLeft = 3.5 * charWidth
      horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(2)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(10 * charWidth - horizontalScrollbarNode.scrollLeft)) + 'px, ' + (4 * lineHeightInPixels - verticalScrollbarNode.scrollTop) + 'px)')
      expect(cursorNodes[1].style['-webkit-transform']).toBe('translate(' + (Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)) + 'px, ' + (8 * lineHeightInPixels - verticalScrollbarNode.scrollTop) + 'px)')
      editor.onDidChangeCursorPosition(cursorMovedListener = jasmine.createSpy('cursorMovedListener'))
      cursor3.setScreenPosition([4, 11], {
        autoscroll: false
      })
      runAnimationFrames()

      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)) + 'px, ' + (4 * lineHeightInPixels - verticalScrollbarNode.scrollTop) + 'px)')
      expect(cursorMovedListener).toHaveBeenCalled()
      cursor3.destroy()
      runAnimationFrames()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(1)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)) + 'px, ' + (8 * lineHeightInPixels - verticalScrollbarNode.scrollTop) + 'px)')
    })

    it('accounts for character widths when positioning cursors', function () {
      component.setFontFamily('sans-serif')
      editor.setCursorScreenPosition([0, 16])
      runAnimationFrames()

      let cursor = componentNode.querySelector('.cursor')
      let cursorRect = cursor.getBoundingClientRect()
      let cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.syntax--storage.syntax--type.syntax--function.syntax--js').firstChild
      let range = document.createRange()
      range.setStart(cursorLocationTextNode, 0)
      range.setEnd(cursorLocationTextNode, 1)
      let rangeRect = range.getBoundingClientRect()
      expect(cursorRect.left).toBeCloseTo(rangeRect.left, 0)
      expect(cursorRect.width).toBeCloseTo(rangeRect.width, 0)
    })

    it('accounts for the width of paired characters when positioning cursors', function () {
      component.setFontFamily('sans-serif')
      editor.setText('he\u0301y')
      editor.setCursorBufferPosition([0, 3])
      runAnimationFrames()

      let cursor = componentNode.querySelector('.cursor')
      let cursorRect = cursor.getBoundingClientRect()
      let cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.syntax--source.syntax--js').childNodes[0]
      let range = document.createRange(cursorLocationTextNode)
      range.setStart(cursorLocationTextNode, 3)
      range.setEnd(cursorLocationTextNode, 4)
      let rangeRect = range.getBoundingClientRect()
      expect(cursorRect.left).toBeCloseTo(rangeRect.left, 0)
      expect(cursorRect.width).toBeCloseTo(rangeRect.width, 0)
    })

    it('positions cursors after the fold-marker when a fold ends the line', function () {
      editor.foldBufferRow(0)
      runAnimationFrames()
      editor.setCursorScreenPosition([0, 30])
      runAnimationFrames()

      let cursorRect = componentNode.querySelector('.cursor').getBoundingClientRect()
      let foldMarkerRect = componentNode.querySelector('.fold-marker').getBoundingClientRect()
      expect(cursorRect.left).toBeCloseTo(foldMarkerRect.right, 0)
    })

    it('positions cursors correctly after character widths are changed via a stylesheet change', function () {
      component.setFontFamily('sans-serif')
      editor.setCursorScreenPosition([0, 16])
      runAnimationFrames(true)

      atom.styles.addStyleSheet('.syntax--function.syntax--js {\n  font-weight: bold;\n}', {
        context: 'atom-text-editor'
      })
      runAnimationFrames(true)

      let cursor = componentNode.querySelector('.cursor')
      let cursorRect = cursor.getBoundingClientRect()
      let cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.syntax--storage.syntax--type.syntax--function.syntax--js').firstChild
      let range = document.createRange()
      range.setStart(cursorLocationTextNode, 0)
      range.setEnd(cursorLocationTextNode, 1)
      let rangeRect = range.getBoundingClientRect()
      expect(cursorRect.left).toBeCloseTo(rangeRect.left, 0)
      expect(cursorRect.width).toBeCloseTo(rangeRect.width, 0)
      atom.themes.removeStylesheet('test')
    })

    it('sets the cursor to the default character width at the end of a line', function () {
      editor.setCursorScreenPosition([0, Infinity])
      runAnimationFrames()
      let cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.offsetWidth).toBeCloseTo(charWidth, 0)
    })

    it('gives the cursor a non-zero width even if it\'s inside atomic tokens', function () {
      editor.setCursorScreenPosition([1, 0])
      runAnimationFrames()
      let cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.offsetWidth).toBeCloseTo(charWidth, 0)
    })

    it('blinks cursors when they are not moving', async function () {
      let cursorsNode = componentNode.querySelector('.cursors')
      wrapperNode.focus()
      runAnimationFrames()
      expect(cursorsNode.classList.contains('blink-off')).toBe(false)
      advanceClock(component.cursorBlinkPeriod / 2)
      runAnimationFrames()
      expect(cursorsNode.classList.contains('blink-off')).toBe(true)
      advanceClock(component.cursorBlinkPeriod / 2)
      runAnimationFrames()
      expect(cursorsNode.classList.contains('blink-off')).toBe(false)
      editor.moveRight()
      runAnimationFrames()
      expect(cursorsNode.classList.contains('blink-off')).toBe(false)
      advanceClock(component.cursorBlinkResumeDelay)
      runAnimationFrames(true)
      expect(cursorsNode.classList.contains('blink-off')).toBe(false)
      advanceClock(component.cursorBlinkPeriod / 2)
      runAnimationFrames()
      expect(cursorsNode.classList.contains('blink-off')).toBe(true)
    })

    it('renders cursors that are associated with empty selections', function () {
      editor.update({showCursorOnSelection: true})
      editor.setSelectedScreenRange([[0, 4], [4, 6]])
      editor.addCursorAtScreenPosition([6, 8])
      runAnimationFrames()
      let cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(2)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(6 * charWidth)) + 'px, ' + (4 * lineHeightInPixels) + 'px)')
      expect(cursorNodes[1].style['-webkit-transform']).toBe('translate(' + (Math.round(8 * charWidth)) + 'px, ' + (6 * lineHeightInPixels) + 'px)')
    })

    it('does not render cursors that are associated with non-empty selections when showCursorOnSelection is false', function () {
      editor.update({showCursorOnSelection: false})
      editor.setSelectedScreenRange([[0, 4], [4, 6]])
      editor.addCursorAtScreenPosition([6, 8])
      runAnimationFrames()
      let cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe(1)
      expect(cursorNodes[0].style['-webkit-transform']).toBe('translate(' + (Math.round(8 * charWidth)) + 'px, ' + (6 * lineHeightInPixels) + 'px)')
    })

    it('updates cursor positions when the line height changes', function () {
      editor.setCursorBufferPosition([1, 10])
      component.setLineHeight(2)
      runAnimationFrames()
      let cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.style['-webkit-transform']).toBe('translate(' + (Math.round(10 * editor.getDefaultCharWidth())) + 'px, ' + (editor.getLineHeightInPixels()) + 'px)')
    })

    it('updates cursor positions when the font size changes', function () {
      editor.setCursorBufferPosition([1, 10])
      component.setFontSize(10)
      runAnimationFrames()
      let cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.style['-webkit-transform']).toBe('translate(' + (Math.round(10 * editor.getDefaultCharWidth())) + 'px, ' + (editor.getLineHeightInPixels()) + 'px)')
    })

    it('updates cursor positions when the font family changes', function () {
      editor.setCursorBufferPosition([1, 10])
      component.setFontFamily('sans-serif')
      runAnimationFrames()
      let cursorNode = componentNode.querySelector('.cursor')
      let left = wrapperNode.pixelPositionForScreenPosition([1, 10]).left
      expect(cursorNode.style['-webkit-transform']).toBe('translate(' + (Math.round(left)) + 'px, ' + (editor.getLineHeightInPixels()) + 'px)')
    })
  })

  describe('selection rendering', function () {
    let scrollViewClientLeft, scrollViewNode

    beforeEach(function () {
      scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left
    })

    it('renders 1 region for 1-line selections', function () {
      editor.setSelectedScreenRange([[1, 6], [1, 10]])
      runAnimationFrames()

      let regions = componentNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe(1)

      let regionRect = regions[0].getBoundingClientRect()
      expect(regionRect.top).toBe(1 * lineHeightInPixels)
      expect(regionRect.height).toBe(1 * lineHeightInPixels)
      expect(regionRect.left).toBeCloseTo(scrollViewClientLeft + 6 * charWidth, 0)
      expect(regionRect.width).toBeCloseTo(4 * charWidth, 0)
    })

    it('renders 2 regions for 2-line selections', function () {
      editor.setSelectedScreenRange([[1, 6], [2, 10]])
      runAnimationFrames()

      let tileNode = component.tileNodesForLines()[0]
      let regions = tileNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe(2)

      let region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe(1 * lineHeightInPixels)
      expect(region1Rect.height).toBe(1 * lineHeightInPixels)
      expect(region1Rect.left).toBeCloseTo(scrollViewClientLeft + 6 * charWidth, 0)
      expect(region1Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      let region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe(2 * lineHeightInPixels)
      expect(region2Rect.height).toBe(1 * lineHeightInPixels)
      expect(region2Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region2Rect.width).toBeCloseTo(10 * charWidth, 0)
    })

    it('renders 3 regions per tile for selections with more than 2 lines', function () {
      editor.setSelectedScreenRange([[0, 6], [5, 10]])
      runAnimationFrames()

      let region1Rect, region2Rect, region3Rect, regions, tileNode
      tileNode = component.tileNodesForLines()[0]
      regions = tileNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe(3)

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe(0)
      expect(region1Rect.height).toBe(1 * lineHeightInPixels)
      expect(region1Rect.left).toBeCloseTo(scrollViewClientLeft + 6 * charWidth, 0)
      expect(region1Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe(1 * lineHeightInPixels)
      expect(region2Rect.height).toBe(1 * lineHeightInPixels)
      expect(region2Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region2Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      region3Rect = regions[2].getBoundingClientRect()
      expect(region3Rect.top).toBe(2 * lineHeightInPixels)
      expect(region3Rect.height).toBe(1 * lineHeightInPixels)
      expect(region3Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region3Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      tileNode = component.tileNodesForLines()[1]
      regions = tileNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe(3)

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe(3 * lineHeightInPixels)
      expect(region1Rect.height).toBe(1 * lineHeightInPixels)
      expect(region1Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region1Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe(4 * lineHeightInPixels)
      expect(region2Rect.height).toBe(1 * lineHeightInPixels)
      expect(region2Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region2Rect.right).toBeCloseTo(tileNode.getBoundingClientRect().right, 0)

      region3Rect = regions[2].getBoundingClientRect()
      expect(region3Rect.top).toBe(5 * lineHeightInPixels)
      expect(region3Rect.height).toBe(1 * lineHeightInPixels)
      expect(region3Rect.left).toBeCloseTo(scrollViewClientLeft + 0, 0)
      expect(region3Rect.width).toBeCloseTo(10 * charWidth, 0)
    })

    it('does not render empty selections', function () {
      editor.addSelectionForBufferRange([[2, 2], [2, 2]])
      runAnimationFrames()
      expect(editor.getSelections()[0].isEmpty()).toBe(true)
      expect(editor.getSelections()[1].isEmpty()).toBe(true)
      expect(componentNode.querySelectorAll('.selection').length).toBe(0)
    })

    it('updates selections when the line height changes', function () {
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setLineHeight(2)
      runAnimationFrames()
      let selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe(editor.getLineHeightInPixels())
    })

    it('updates selections when the font size changes', function () {
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontSize(10)

      runAnimationFrames()

      let selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe(editor.getLineHeightInPixels())
      expect(selectionNode.offsetLeft).toBeCloseTo(6 * editor.getDefaultCharWidth(), 0)
    })

    it('updates selections when the font family changes', function () {
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontFamily('sans-serif')

      runAnimationFrames()

      let selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe(editor.getLineHeightInPixels())
      expect(selectionNode.offsetLeft).toBeCloseTo(wrapperNode.pixelPositionForScreenPosition([1, 6]).left, 0)
    })

    it('will flash the selection when flash:true is passed to editor::setSelectedBufferRange', async function () {
      editor.setSelectedBufferRange([[1, 6], [1, 10]], {
        flash: true
      })
      runAnimationFrames()

      let selectionNode = componentNode.querySelector('.selection')
      expect(selectionNode.classList.contains('flash')).toBe(true)

      advanceClock(editor.selectionFlashDuration)

      editor.setSelectedBufferRange([[1, 5], [1, 7]], {
        flash: true
      })
      runAnimationFrames()

      expect(selectionNode.classList.contains('flash')).toBe(true)
    })
  })

  describe('line decoration rendering', async function () {
    let decoration, marker

    beforeEach(async function () {
      marker = editor.addMarkerLayer({
        maintainHistory: true
      }).markBufferRange([[2, 13], [3, 15]], {
        invalidate: 'inside'
      })
      decoration = editor.decorateMarker(marker, {
        type: ['line-number', 'line'],
        'class': 'a'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
    })

    it('applies line decoration classes to lines and line numbers', async function () {
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(true)
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      let marker2 = editor.markBufferRange([[9, 0], [9, 0]])
      editor.decorateMarker(marker2, {
        type: ['line-number', 'line'],
        'class': 'b'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      expect(lineAndLineNumberHaveClass(9, 'b')).toBe(true)

      editor.foldBufferRow(5)
      runAnimationFrames()

      expect(lineAndLineNumberHaveClass(9, 'b')).toBe(false)
      expect(lineAndLineNumberHaveClass(6, 'b')).toBe(true)
    })

    it('only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped', async function () {
      editor.setText('a line that wraps, ok')
      editor.setSoftWrapped(true)
      componentNode.style.width = 16 * charWidth + 'px'
      component.measureDimensions()

      runAnimationFrames()
      marker.destroy()
      marker = editor.markBufferRange([[0, 0], [0, 2]])
      editor.decorateMarker(marker, {
        type: ['line-number', 'line'],
        'class': 'b'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(lineNumberHasClass(0, 'b')).toBe(true)
      expect(lineNumberHasClass(1, 'b')).toBe(false)
      marker.setBufferRange([[0, 0], [0, Infinity]])
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(lineNumberHasClass(0, 'b')).toBe(true)
      expect(lineNumberHasClass(1, 'b')).toBe(true)
    })

    it('updates decorations when markers move', async function () {
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe(false)

      editor.getBuffer().insert([0, 0], '\n')
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(5, 'a')).toBe(false)

      marker.setBufferRange([[4, 4], [6, 4]])
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(5, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(6, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(7, 'a')).toBe(false)
    })

    it('remove decoration classes when decorations are removed', async function () {
      decoration.destroy()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      expect(lineNumberHasClass(1, 'a')).toBe(false)
      expect(lineNumberHasClass(2, 'a')).toBe(false)
      expect(lineNumberHasClass(3, 'a')).toBe(false)
      expect(lineNumberHasClass(4, 'a')).toBe(false)
    })

    it('removes decorations when their marker is invalidated', async function () {
      editor.getBuffer().insert([3, 2], 'n')
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(marker.isValid()).toBe(false)
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe(false)
      editor.undo()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(marker.isValid()).toBe(true)
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe(false)
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe(true)
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe(false)
    })

    it('removes decorations when their marker is destroyed', async function () {
      marker.destroy()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      expect(lineNumberHasClass(1, 'a')).toBe(false)
      expect(lineNumberHasClass(2, 'a')).toBe(false)
      expect(lineNumberHasClass(3, 'a')).toBe(false)
      expect(lineNumberHasClass(4, 'a')).toBe(false)
    })

    describe('when the decoration\'s "onlyHead" property is true', async function () {
      it('only applies the decoration\'s class to lines containing the marker\'s head', async function () {
        editor.decorateMarker(marker, {
          type: ['line-number', 'line'],
          'class': 'only-head',
          onlyHead: true
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()
        expect(lineAndLineNumberHaveClass(1, 'only-head')).toBe(false)
        expect(lineAndLineNumberHaveClass(2, 'only-head')).toBe(false)
        expect(lineAndLineNumberHaveClass(3, 'only-head')).toBe(true)
        expect(lineAndLineNumberHaveClass(4, 'only-head')).toBe(false)
      })
    })

    describe('when the decoration\'s "onlyEmpty" property is true', function () {
      it('only applies the decoration when its marker is empty', async function () {
        editor.decorateMarker(marker, {
          type: ['line-number', 'line'],
          'class': 'only-empty',
          onlyEmpty: true
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe(false)
        expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe(false)

        marker.clearTail()
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe(false)
        expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe(true)
      })
    })

    describe('when the decoration\'s "onlyNonEmpty" property is true', function () {
      it('only applies the decoration when its marker is non-empty', async function () {
        editor.decorateMarker(marker, {
          type: ['line-number', 'line'],
          'class': 'only-non-empty',
          onlyNonEmpty: true
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe(true)
        expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe(true)

        marker.clearTail()
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe(false)
        expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe(false)
      })
    })
  })

  describe('block decorations rendering', function () {
    let markerLayer

    function createBlockDecorationBeforeScreenRow(screenRow, {className}) {
      let item = document.createElement("div")
      item.className = className || ""
      let blockDecoration = editor.decorateMarker(
        markerLayer.markScreenPosition([screenRow, 0], {invalidate: "never"}),
        {type: "block", item: item, position: "before"}
      )
      return [item, blockDecoration]
    }

    function createBlockDecorationAfterScreenRow(screenRow, {className}) {
      let item = document.createElement("div")
      item.className = className || ""
      let blockDecoration = editor.decorateMarker(
        markerLayer.markScreenPosition([screenRow, 0], {invalidate: "never"}),
        {type: "block", item: item, position: "after"}
      )
      return [item, blockDecoration]
    }

    beforeEach(function () {
      markerLayer = editor.addMarkerLayer()
      wrapperNode.style.height = 5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()
    })

    afterEach(function () {
      atom.themes.removeStylesheet('test')
    })

    it("renders visible and yet-to-be-measured block decorations, inserting them between the appropriate lines and refreshing them as needed", async function () {
      let [item1, blockDecoration1] = createBlockDecorationBeforeScreenRow(0, {className: "decoration-1"})
      let [item2, blockDecoration2] = createBlockDecorationBeforeScreenRow(2, {className: "decoration-2"})
      let [item3, blockDecoration3] = createBlockDecorationBeforeScreenRow(4, {className: "decoration-3"})
      let [item4, blockDecoration4] = createBlockDecorationBeforeScreenRow(7, {className: "decoration-4"})
      let [item5, blockDecoration5] = createBlockDecorationAfterScreenRow(7, {className: "decoration-5"})
      let [item6, blockDecoration6] = createBlockDecorationAfterScreenRow(12, {className: "decoration-6"})

      atom.styles.addStyleSheet(
        `atom-text-editor .decoration-1 { width: 30px; height: 80px; }
         atom-text-editor .decoration-2 { width: 30px; height: 40px; }
         atom-text-editor .decoration-3 { width: 30px; height: 100px; }
         atom-text-editor .decoration-4 { width: 30px; height: 120px; }
         atom-text-editor .decoration-5 { width: 30px; height: 42px; }
         atom-text-editor .decoration-6 { width: 30px; height: 22px; }`,
         {context: 'atom-text-editor'}
      )
      runAnimationFrames()
      expect(component.getDomNode().querySelectorAll(".line").length).toBe(7)
      expect(verticalScrollbarNode.scrollHeight).toBe(editor.getScreenLineCount() * editor.getLineHeightInPixels() + 80 + 40 + 100 + 120 + 42 + 22)
      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 80 + 40 + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 100 + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 120 + 42 + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
      expect(component.getTopmostDOMNode().querySelector(".decoration-1")).toBe(item1)
      expect(component.getTopmostDOMNode().querySelector(".decoration-2")).toBe(item2)
      expect(component.getTopmostDOMNode().querySelector(".decoration-3")).toBe(item3)
      expect(component.getTopmostDOMNode().querySelector(".decoration-4")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-5")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-6")).toBeNull()
      expect(item1.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 0)
      expect(item2.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 2 + 80)
      expect(item3.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 4 + 80 + 40)

      editor.setCursorScreenPosition([0, 0])
      editor.insertNewline()
      blockDecoration1.destroy()
      runAnimationFrames()
      expect(component.getDomNode().querySelectorAll(".line").length).toBe(7)
      expect(verticalScrollbarNode.scrollHeight).toBe(editor.getScreenLineCount() * editor.getLineHeightInPixels() + 40 + 100 + 120 + 42 + 22)
      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 100 + 40 + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 120 + 42 + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
      expect(component.getTopmostDOMNode().querySelector(".decoration-1")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-2")).toBe(item2)
      expect(component.getTopmostDOMNode().querySelector(".decoration-3")).toBe(item3)
      expect(component.getTopmostDOMNode().querySelector(".decoration-4")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-5")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-6")).toBeNull()
      expect(item2.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 3)
      expect(item3.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 5 + 40)

      atom.styles.addStyleSheet(
        'atom-text-editor .decoration-2 { height: 60px; }',
        {context: 'atom-text-editor'}
      )

      runAnimationFrames() // causes the DOM to update and to retrieve new styles
      runAnimationFrames() // applies the changes
      expect(component.getDomNode().querySelectorAll(".line").length).toBe(7)
      expect(verticalScrollbarNode.scrollHeight).toBe(editor.getScreenLineCount() * editor.getLineHeightInPixels() + 60 + 100 + 120 + 42 + 22)
      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 100 + 60 + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 120 + 42 + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
      expect(component.getTopmostDOMNode().querySelector(".decoration-1")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-2")).toBe(item2)
      expect(component.getTopmostDOMNode().querySelector(".decoration-3")).toBe(item3)
      expect(component.getTopmostDOMNode().querySelector(".decoration-4")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-5")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-6")).toBeNull()
      expect(item2.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 3)
      expect(item3.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 5 + 60)

      item2.style.height = "20px"
      wrapperNode.invalidateBlockDecorationDimensions(blockDecoration2)
      runAnimationFrames() // causes the DOM to update and to retrieve new styles
      runAnimationFrames() // applies the changes
      expect(component.getDomNode().querySelectorAll(".line").length).toBe(9)
      expect(verticalScrollbarNode.scrollHeight).toBe(editor.getScreenLineCount() * editor.getLineHeightInPixels() + 20 + 100 + 120 + 42 + 22)
      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 100 + 20 + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 120 + 42 + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
      expect(component.getTopmostDOMNode().querySelector(".decoration-1")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-2")).toBe(item2)
      expect(component.getTopmostDOMNode().querySelector(".decoration-3")).toBe(item3)
      expect(component.getTopmostDOMNode().querySelector(".decoration-4")).toBe(item4)
      expect(component.getTopmostDOMNode().querySelector(".decoration-5")).toBe(item5)
      expect(component.getTopmostDOMNode().querySelector(".decoration-6")).toBeNull()
      expect(item2.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 3)
      expect(item3.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 5 + 20)
      expect(item4.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 8 + 20 + 100)
      expect(item5.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 8 + 20 + 100 + 120 + lineHeightInPixels)

      item6.style.height = "33px"
      wrapperNode.invalidateBlockDecorationDimensions(blockDecoration6)
      runAnimationFrames() // causes the DOM to update and to retrieve new styles
      runAnimationFrames() // applies the changes
      expect(component.getDomNode().querySelectorAll(".line").length).toBe(9)
      expect(verticalScrollbarNode.scrollHeight).toBe(editor.getScreenLineCount() * editor.getLineHeightInPixels() + 20 + 100 + 120 + 42 + 33)
      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 100 + 20 + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 120 + 42 + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
      expect(component.getTopmostDOMNode().querySelector(".decoration-1")).toBeNull()
      expect(component.getTopmostDOMNode().querySelector(".decoration-2")).toBe(item2)
      expect(component.getTopmostDOMNode().querySelector(".decoration-3")).toBe(item3)
      expect(component.getTopmostDOMNode().querySelector(".decoration-4")).toBe(item4)
      expect(component.getTopmostDOMNode().querySelector(".decoration-5")).toBe(item5)
      expect(component.getTopmostDOMNode().querySelector(".decoration-6")).toBeNull()
      expect(item2.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 3)
      expect(item3.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 5 + 20)
      expect(item4.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 8 + 20 + 100)
      expect(item5.getBoundingClientRect().top).toBe(editor.getLineHeightInPixels() * 8 + 20 + 100 + 120 + lineHeightInPixels)
    })

    it("correctly sets screen rows on block decoration and ruler nodes, both initially and when decorations move", function () {
      let [item, blockDecoration] = createBlockDecorationBeforeScreenRow(0, {className: "decoration-1"})
      atom.styles.addStyleSheet(
        'atom-text-editor .decoration-1 { width: 30px; height: 80px; }',
         {context: 'atom-text-editor'}
      )

      runAnimationFrames()
      const line0 = component.lineNodeForScreenRow(0)
      expect(item.previousSibling.dataset.screenRow).toBe("0")
      expect(item.dataset.screenRow).toBe("0")
      expect(item.nextSibling.dataset.screenRow).toBe("0")
      expect(line0.previousSibling).toBe(item.nextSibling)

      editor.setCursorBufferPosition([0, 0])
      editor.insertNewline()
      runAnimationFrames()
      const line1 = component.lineNodeForScreenRow(1)
      expect(item.previousSibling.dataset.screenRow).toBe("1")
      expect(item.dataset.screenRow).toBe("1")
      expect(item.nextSibling.dataset.screenRow).toBe("1")
      expect(line1.previousSibling).toBe(item.nextSibling)

      editor.setCursorBufferPosition([0, 0])
      editor.insertNewline()
      runAnimationFrames()
      const line2 = component.lineNodeForScreenRow(2)
      expect(item.previousSibling.dataset.screenRow).toBe("2")
      expect(item.dataset.screenRow).toBe("2")
      expect(item.nextSibling.dataset.screenRow).toBe("2")
      expect(line2.previousSibling).toBe(item.nextSibling)

      blockDecoration.getMarker().setHeadBufferPosition([4, 0])
      runAnimationFrames()
      const line4 = component.lineNodeForScreenRow(4)
      expect(item.previousSibling.dataset.screenRow).toBe("4")
      expect(item.dataset.screenRow).toBe("4")
      expect(item.nextSibling.dataset.screenRow).toBe("4")
      expect(line4.previousSibling).toBe(item.nextSibling)
    })

    it('measures block decorations taking into account both top and bottom margins of the element and its children', function () {
      let [item, blockDecoration] = createBlockDecorationBeforeScreenRow(0, {className: "decoration-1"})
      let child = document.createElement("div")
      child.style.height = "7px"
      child.style.width = "30px"
      child.style.marginBottom = "20px"
      item.appendChild(child)
      atom.styles.addStyleSheet(
        'atom-text-editor .decoration-1 { width: 30px; margin-top: 10px; }',
         {context: 'atom-text-editor'}
      )

      runAnimationFrames() // causes the DOM to update and to retrieve new styles
      runAnimationFrames() // applies the changes

      expect(component.tileNodesForLines()[0].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + 10 + 7 + 20 + "px")
      expect(component.tileNodesForLines()[0].style.webkitTransform).toBe("translate3d(0px, 0px, 0px)")
      expect(component.tileNodesForLines()[1].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[1].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight}px, 0px)`)
      expect(component.tileNodesForLines()[2].style.height).toBe(TILE_SIZE * editor.getLineHeightInPixels() + "px")
      expect(component.tileNodesForLines()[2].style.webkitTransform).toBe(`translate3d(0px, ${component.tileNodesForLines()[0].offsetHeight + component.tileNodesForLines()[1].offsetHeight}px, 0px)`)
    })

    it('allows the same block decoration item to be moved from one tile to another in the same animation frame', function () {
      let [item, blockDecoration] = createBlockDecorationBeforeScreenRow(5, {className: "decoration-1"})
      runAnimationFrames()
      expect(component.tileNodesForLines()[0].querySelector('.decoration-1')).toBeNull()
      expect(component.tileNodesForLines()[1].querySelector('.decoration-1')).toBe(item)

      blockDecoration.getMarker().setHeadBufferPosition([0, 0])
      runAnimationFrames()
      expect(component.tileNodesForLines()[0].querySelector('.decoration-1')).toBe(item)
      expect(component.tileNodesForLines()[1].querySelector('.decoration-1')).toBeNull()
    })
  })

  describe('highlight decoration rendering', function () {
    let decoration, marker, scrollViewClientLeft

    beforeEach(async function () {
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left
      marker = editor.addMarkerLayer({
        maintainHistory: true
      }).markBufferRange([[2, 13], [3, 15]], {
        invalidate: 'inside'
      })
      decoration = editor.decorateMarker(marker, {
        type: 'highlight',
        'class': 'test-highlight'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
    })

    it('does not render highlights for off-screen lines until they come on-screen', async function () {
      wrapperNode.style.height = 2.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      marker = editor.markBufferRange([[9, 2], [9, 4]], {
        invalidate: 'inside'
      })
      editor.decorateMarker(marker, {
        type: 'highlight',
        'class': 'some-highlight'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(component.presenter.endRow).toBeLessThan(9)
      let regions = componentNode.querySelectorAll('.some-highlight .region')
      expect(regions.length).toBe(0)
      verticalScrollbarNode.scrollTop = 6 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)

      expect(component.presenter.endRow).toBeGreaterThan(8)
      regions = componentNode.querySelectorAll('.some-highlight .region')
      expect(regions.length).toBe(1)
      let regionRect = regions[0].style
      expect(regionRect.top).toBe(0 + 'px')
      expect(regionRect.height).toBe(1 * lineHeightInPixels + 'px')
      expect(regionRect.left).toBe(Math.round(2 * charWidth) + 'px')
      expect(regionRect.width).toBe(Math.round(2 * charWidth) + 'px')
    })

    it('renders highlights decoration\'s marker is added', function () {
      let regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe(2)
    })

    it('removes highlights when a decoration is removed', async function () {
      decoration.destroy()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      let regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe(0)
    })

    it('does not render a highlight that is within a fold', async function () {
      editor.foldBufferRow(1)
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      expect(componentNode.querySelectorAll('.test-highlight').length).toBe(0)
    })

    it('removes highlights when a decoration\'s marker is destroyed', async function () {
      marker.destroy()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      let regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe(0)
    })

    it('only renders highlights when a decoration\'s marker is valid', async function () {
      editor.getBuffer().insert([3, 2], 'n')
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(marker.isValid()).toBe(false)
      let regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe(0)
      editor.getBuffer().undo()
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(marker.isValid()).toBe(true)
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe(2)
    })

    it('allows multiple space-delimited decoration classes', async function () {
      decoration.setProperties({
        type: 'highlight',
        'class': 'foo bar'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      expect(componentNode.querySelectorAll('.foo.bar').length).toBe(2)
      decoration.setProperties({
        type: 'highlight',
        'class': 'bar baz'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      expect(componentNode.querySelectorAll('.bar.baz').length).toBe(2)
    })

    it('renders classes on the regions directly if "deprecatedRegionClass" option is defined', async function () {
      decoration = editor.decorateMarker(marker, {
        type: 'highlight',
        'class': 'test-highlight',
        deprecatedRegionClass: 'test-highlight-region'
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()
      let regions = componentNode.querySelectorAll('.test-highlight .region.test-highlight-region')
      expect(regions.length).toBe(2)
    })

    describe('when flashing a decoration via Decoration::flash()', function () {
      let highlightNode

      beforeEach(function () {
        highlightNode = componentNode.querySelectorAll('.test-highlight')[1]
      })

      it('adds and removes the flash class specified in ::flash', async function () {
        expect(highlightNode.classList.contains('flash-class')).toBe(false)
        decoration.flash('flash-class', 10)
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(highlightNode.classList.contains('flash-class')).toBe(true)
        advanceClock(10)
        expect(highlightNode.classList.contains('flash-class')).toBe(false)
      })

      describe('when ::flash is called again before the first has finished', function () {
        it('removes the class from the decoration highlight before adding it for the second ::flash call', async function () {
          decoration.flash('flash-class', 500)
          await decorationsUpdatedPromise(editor)
          runAnimationFrames()
          expect(highlightNode.classList.contains('flash-class')).toBe(true)

          decoration.flash('flash-class', 500)
          await decorationsUpdatedPromise(editor)
          runAnimationFrames()

          expect(highlightNode.classList.contains('flash-class')).toBe(false)
          runAnimationFrames()
          expect(highlightNode.classList.contains('flash-class')).toBe(true)
          advanceClock(500)
          expect(highlightNode.classList.contains('flash-class')).toBe(false)
        })
      })
    })

    describe('when a decoration\'s marker moves', function () {
      it('moves rendered highlights when the buffer is changed', async function () {
        let regionStyle = componentNode.querySelector('.test-highlight .region').style
        let originalTop = parseInt(regionStyle.top)
        expect(originalTop).toBe(2 * lineHeightInPixels)

        editor.getBuffer().insert([0, 0], '\n')
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        let newTop = parseInt(regionStyle.top)
        expect(newTop).toBe(0)
      })

      it('moves rendered highlights when the marker is manually moved', async function () {
        let regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe(2 * lineHeightInPixels)

        marker.setBufferRange([[5, 8], [5, 13]])
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe(2 * lineHeightInPixels)
      })
    })

    describe('when a decoration is updated via Decoration::update', function () {
      it('renders the decoration\'s new params', async function () {
        expect(componentNode.querySelector('.test-highlight')).toBeTruthy()
        decoration.setProperties({
          type: 'highlight',
          'class': 'new-test-highlight'
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()
        expect(componentNode.querySelector('.test-highlight')).toBeFalsy()
        expect(componentNode.querySelector('.new-test-highlight')).toBeTruthy()
      })
    })
  })

  describe('overlay decoration rendering', function () {
    let gutterWidth, item

    beforeEach(function () {
      item = document.createElement('div')
      item.classList.add('overlay-test')
      item.style.background = 'red'
      gutterWidth = componentNode.querySelector('.gutter').offsetWidth
    })

    describe('when the marker is empty', function () {
      it('renders an overlay decoration when added and removes the overlay when the decoration is destroyed', async function () {
        let marker = editor.markBufferRange([[2, 13], [2, 13]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe(item)

        decoration.destroy()
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe(null)
      })

      it('renders the overlay element with the CSS class specified by the decoration', async function () {
        let marker = editor.markBufferRange([[2, 13], [2, 13]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          'class': 'my-overlay',
          item: item
        })

        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay.my-overlay')
        expect(overlay).not.toBe(null)
        let child = overlay.querySelector('.overlay-test')
        expect(child).toBe(item)
      })
    })

    describe('when the marker is not empty', function () {
      it('renders at the head of the marker by default', async function () {
        let marker = editor.markBufferRange([[2, 5], [2, 10]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })

        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        let position = wrapperNode.pixelPositionForBufferPosition([2, 10])
        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        expect(overlay.style.left).toBe(Math.round(position.left + gutterWidth) + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')
      })
    })

    describe('positioning the overlay when near the edge of the editor', function () {
      let itemHeight, itemWidth, windowHeight, windowWidth

      beforeEach(async function () {
        atom.storeWindowDimensions()
        itemWidth = Math.round(4 * editor.getDefaultCharWidth())
        itemHeight = 4 * editor.getLineHeightInPixels()
        windowWidth = Math.round(gutterWidth + 30 * editor.getDefaultCharWidth())
        windowHeight = 10 * editor.getLineHeightInPixels()
        item.style.width = itemWidth + 'px'
        item.style.height = itemHeight + 'px'
        wrapperNode.style.width = windowWidth + 'px'
        wrapperNode.style.height = windowHeight + 'px'
        editor.update({autoHeight: false})
        await atom.setWindowDimensions({
          width: windowWidth,
          height: windowHeight
        })

        component.measureDimensions()
        component.measureWindowSize()
        runAnimationFrames()
      })

      afterEach(function () {
        atom.restoreWindowDimensions()
      })

      it('slides horizontally left when near the right edge on #win32 and #darwin', async function () {
        let marker = editor.markBufferRange([[0, 26], [0, 26]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        let position = wrapperNode.pixelPositionForBufferPosition([0, 26])
        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        if (process.platform == 'darwin') { // Result is 359px on win32, expects 375px
          expect(overlay.style.left).toBe(Math.round(position.left + gutterWidth) + 'px')
        }
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        editor.insertText('a')
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(overlay.style.left).toBe(window.innerWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        editor.insertText('b')
        await decorationsUpdatedPromise(editor)
        runAnimationFrames()

        expect(overlay.style.left).toBe(window.innerWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        // window size change
        const innerWidthBefore = window.innerWidth
        await atom.setWindowDimensions({
          width: Math.round(gutterWidth + 20 * editor.getDefaultCharWidth()),
          height: windowHeight,
        })
        // wait for window to resize :(
        await conditionPromise(() => {
          return window.innerWidth !== innerWidthBefore
        })

        atom.views.performDocumentPoll()
        runAnimationFrames()

        expect(overlay.style.left).toBe(window.innerWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')
      })
    })
  })

  describe('hidden input field', function () {
    it('renders the hidden input field at the position of the last cursor if the cursor is on screen and the editor is focused', async function () {
      editor.setVerticalScrollMargin(0)
      editor.setHorizontalScrollMargin(0)
      let inputNode = componentNode.querySelector('.hidden-input')
      wrapperNode.style.height = 5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(editor.getCursorScreenPosition()).toEqual([0, 0])

      wrapperNode.setScrollTop(3 * lineHeightInPixels)
      wrapperNode.setScrollLeft(3 * charWidth)
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      editor.setCursorBufferPosition([5, 4], {
        autoscroll: false
      })
      await decorationsUpdatedPromise(editor)
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      wrapperNode.focus()
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe((5 * lineHeightInPixels) - wrapperNode.getScrollTop())
      expect(inputNode.offsetLeft).toBeCloseTo((4 * charWidth) - wrapperNode.getScrollLeft(), 0)

      inputNode.blur()
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      editor.setCursorBufferPosition([1, 2], {
        autoscroll: false
      })
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      inputNode.focus()
      runAnimationFrames()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)
    })
  })

  describe('mouse interactions on the lines', function () {
    let linesNode

    beforeEach(function () {
      linesNode = componentNode.querySelector('.lines')
    })

    describe('when the mouse is single-clicked above the first line', function () {
      it('moves the cursor to the start of file buffer position', function () {
        let height
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 3])
        height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = -1
        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))

        runAnimationFrames()
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      })
    })

    describe('when the mouse is single-clicked below the last line', function () {
      it('moves the cursor to the end of file buffer position', function () {
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 0])
        let height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = height * 2

        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
        runAnimationFrames()

        expect(editor.getCursorScreenPosition()).toEqual([0, 3])
      })
    })

    describe('when a non-folded line is single-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('moves the cursor to the nearest screen position', function () {
          wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
          wrapperNode.style.width = 10 * charWidth + 'px'
          editor.update({autoHeight: false})
          component.measureDimensions()
          wrapperNode.setScrollTop(3.5 * lineHeightInPixels)
          wrapperNode.setScrollLeft(2 * charWidth)
          runAnimationFrames()
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8])))
          runAnimationFrames()
          expect(editor.getCursorScreenPosition()).toEqual([4, 8])
        })
      })

      describe('when the shift key is held down', function () {
        it('selects to the nearest screen position', function () {
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), {
            shiftKey: true
          }))
          runAnimationFrames()
          expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [5, 6]])
        })
      })

      describe('when the command key is held down', function () {
        describe('the current cursor position and screen position do not match', function () {
          it('adds a cursor at the nearest screen position', function () {
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), {
              metaKey: true
            }))
            runAnimationFrames()
            expect(editor.getSelectedScreenRanges()).toEqual([[[3, 4], [3, 4]], [[5, 6], [5, 6]]])
          })
        })

        describe('when there are multiple cursors, and one of the cursor\'s screen position is the same as the mouse click screen position', function () {
          it('removes a cursor at the mouse screen position', function () {
            editor.setCursorScreenPosition([3, 4])
            editor.addCursorAtScreenPosition([5, 2])
            editor.addCursorAtScreenPosition([7, 5])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), {
              metaKey: true
            }))
            runAnimationFrames()
            expect(editor.getSelectedScreenRanges()).toEqual([[[5, 2], [5, 2]], [[7, 5], [7, 5]]])
          })
        })

        describe('when there is a single cursor and the click occurs at the cursor\'s screen position', function () {
          it('neither adds a new cursor nor removes the current cursor', function () {
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), {
              metaKey: true
            }))
            runAnimationFrames()
            expect(editor.getSelectedScreenRanges()).toEqual([[[3, 4], [3, 4]]])
          })
        })
      })
    })

    describe('when a non-folded line is double-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('selects the word containing the nearest screen position', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [5, 13]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[6, 6], [6, 6]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[6, 6], [8, 8]])
        })
      })

      describe('when the command key is held down', function () {
        it('selects the word containing the newly-added cursor', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [0, 0]], [[5, 6], [5, 13]]])
        })
      })
    })

    describe('when a non-folded line is triple-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('selects the line containing the nearest screen position', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 3
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [7, 0]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([7, 5]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[7, 5], [8, 8]])
        })
      })

      describe('when the command key is held down', function () {
        it('selects the line containing the newly-added cursor', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 3,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [0, 0]], [[5, 0], [6, 0]]])
        })
      })
    })

    describe('when the mouse is clicked and dragged', function () {
      it('selects to the nearest screen position until the mouse button is released', function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), {
          which: 1
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [10, 0]])
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([12, 0]), {
          which: 1
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [10, 0]])
      })

      it('autoscrolls when the cursor approaches the boundaries of the editor', function () {
        wrapperNode.style.height = '100px'
        wrapperNode.style.width = '100px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)

        linesNode.dispatchEvent(buildMouseEvent('mousedown', {
          clientX: 0,
          clientY: 0
        }, {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 100,
          clientY: 50
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          runAnimationFrames()
        }

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBeGreaterThan(0)
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 100,
          clientY: 100
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          runAnimationFrames()
        }

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        let previousScrollTop = wrapperNode.getScrollTop()
        let previousScrollLeft = wrapperNode.getScrollLeft()

        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 10,
          clientY: 50
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          runAnimationFrames()
        }

        expect(wrapperNode.getScrollTop()).toBe(previousScrollTop)
        expect(wrapperNode.getScrollLeft()).toBeLessThan(previousScrollLeft)
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 10,
          clientY: 10
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          runAnimationFrames()
        }

        expect(wrapperNode.getScrollTop()).toBeLessThan(previousScrollTop)
      })

      it('stops selecting if the mouse is dragged into the dev tools', function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), {
          which: 0
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        runAnimationFrames()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
      })

      it('stops selecting before the buffer is modified during the drag', function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])

        editor.insertText('x')
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 5], [2, 5]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 5], [2, 5]])

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([5, 4]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [5, 4]])

        editor.delete()
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [2, 4]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [2, 4]])
      })

      describe('when the command key is held down', function () {
        it('adds a new selection and selects to the nearest screen position, then merges intersecting selections when the mouse button is released', function () {
          editor.setSelectedScreenRange([[4, 4], [4, 9]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
            which: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
            which: 1
          }))
          runAnimationFrames()

          expect(editor.getSelectedScreenRanges()).toEqual([[[4, 4], [4, 9]], [[2, 4], [6, 8]]])

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([4, 6]), {
            which: 1
          }))
          runAnimationFrames()

          expect(editor.getSelectedScreenRanges()).toEqual([[[4, 4], [4, 9]], [[2, 4], [4, 6]]])
          linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([4, 6]), {
            which: 1
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 4], [4, 9]]])
        })
      })

      describe('when the editor is destroyed while dragging', function () {
        it('cleans up the handlers for window.mouseup and window.mousemove', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
            which: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
            which: 1
          }))
          runAnimationFrames()

          spyOn(window, 'removeEventListener').andCallThrough()
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 10]), {
            which: 1
          }))

          editor.destroy()
          runAnimationFrames()

          for (let call of window.removeEventListener.calls) {
            call.args.pop()
          }
          expect(window.removeEventListener).toHaveBeenCalledWith('mouseup')
          expect(window.removeEventListener).toHaveBeenCalledWith('mousemove')
        })
      })
    })

    describe('when the mouse is double-clicked and dragged', function () {
      it('expands the selection over the nearest word as the cursor moves', function () {
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 2
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [5, 13]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [12, 2]])
        let maximalScrollTop = wrapperNode.getScrollTop()
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [9, 4]])
        expect(wrapperNode.getScrollTop()).toBe(maximalScrollTop)
        linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
      })
    })

    describe('when the mouse is triple-clicked and dragged', function () {
      it('expands the selection over the nearest line as the cursor moves', function () {
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 2
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 3
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [12, 2]])
        let maximalScrollTop = wrapperNode.getScrollTop()
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 4]), {
          which: 1
        }))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [8, 0]])
        expect(wrapperNode.getScrollTop()).toBe(maximalScrollTop)
        linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
      })
    })

    describe('when a fold marker is clicked', function () {
      function clickElementAtPosition (marker, position) {
        linesNode.dispatchEvent(
          buildMouseEvent('mousedown', clientCoordinatesForScreenPosition(position), {target: marker})
        )
      }

      it('unfolds only the selected fold when other folds are on the same line', function () {
        editor.foldBufferRange([[4, 6], [4, 10]])
        editor.foldBufferRange([[4, 15], [4, 20]])
        runAnimationFrames()

        let foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(2)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 6])
        runAnimationFrames()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 15])
        runAnimationFrames()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(0)
        expect(editor.isFoldedAtBufferRow(4)).toBe(false)
      })

      it('unfolds only the selected fold when other folds are inside it', function () {
        editor.foldBufferRange([[4, 10], [4, 15]])
        editor.foldBufferRange([[4, 4], [4, 5]])
        editor.foldBufferRange([[4, 4], [4, 20]])
        runAnimationFrames()
        let foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 4])
        runAnimationFrames()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 4])
        runAnimationFrames()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 10])
        runAnimationFrames()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(0)
        expect(editor.isFoldedAtBufferRow(4)).toBe(false)
      })
    })

    describe('when the horizontal scrollbar is interacted with', function () {
      it('clicking on the scrollbar does not move the cursor', function () {
        let target = horizontalScrollbarNode
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8]), {
          target: target
        }))
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      })
    })
  })

  describe('mouse interactions on the gutter', function () {
    let gutterNode

    beforeEach(function () {
      gutterNode = componentNode.querySelector('.gutter')
    })

    describe('when the component is destroyed', function () {
      it('stops listening for selection events', function () {
        component.destroy()
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
        expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [0, 0]])
      })
    })

    describe('when the gutter is clicked', function () {
      it('selects the clicked row', function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        expect(editor.getSelectedScreenRange()).toEqual([[4, 0], [5, 0]])
      })
    })

    describe('when the gutter is meta-clicked', function () {
      it('creates a new selection for the clicked row', function () {
        editor.setSelectedScreenRange([[3, 0], [3, 2]])
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), {
          metaKey: true
        }))
        expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [5, 0]]])
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
          metaKey: true
        }))
        expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [5, 0]], [[6, 0], [7, 0]]])
      })
    })

    describe('when the gutter is shift-clicked', function () {
      beforeEach(function () {
        editor.setSelectedScreenRange([[3, 4], [4, 5]])
      })

      describe('when the clicked row is before the current selection\'s tail', function () {
        it('selects to the beginning of the clicked row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
            shiftKey: true
          }))
          expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 4]])
        })
      })

      describe('when the clicked row is after the current selection\'s tail', function () {
        it('selects to the beginning of the row following the clicked row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            shiftKey: true
          }))
          expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [7, 0]])
        })
      })
    })

    describe('when the gutter is clicked and dragged', function () {
      describe('when dragging downward', function () {
        it('selects the rows between the start and end of the drag', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
          runAnimationFrames()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])
        })
      })

      describe('when dragging upward', function () {
        it('selects the rows between the start and end of the drag', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
          runAnimationFrames()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2)))
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])
        })
      })

      it('orients the selection appropriately when the mouse moves above or below the initially-clicked row', function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
        runAnimationFrames()
        expect(editor.getLastSelection().isReversed()).toBe(true)
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
        runAnimationFrames()
        expect(editor.getLastSelection().isReversed()).toBe(false)
      })

      it('autoscrolls when the cursor approaches the top or bottom of the editor', function () {
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)

        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        let maxScrollTop = wrapperNode.getScrollTop()

        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(10)))
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(maxScrollTop)

        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBeLessThan(maxScrollTop)
      })

      it('stops selecting if a textInput event occurs during the drag', function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])

        let inputEvent = new Event('textInput')
        inputEvent.data = 'x'
        Object.defineProperty(inputEvent, 'target', {
          get: function () {
            return componentNode.querySelector('.hidden-input')
          }
        })
        componentNode.dispatchEvent(inputEvent)
        runAnimationFrames()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 1], [2, 1]])
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(12)))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 1], [2, 1]])
      })
    })

    describe('when the gutter is meta-clicked and dragged', function () {
      beforeEach(function () {
        editor.setSelectedScreenRange([[3, 0], [3, 2]])
      })

      describe('when dragging downward', function () {
        it('selects the rows between the start and end of the drag', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          runAnimationFrames()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [7, 0]]])
        })

        it('merges overlapping selections when the mouse button is released', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          runAnimationFrames()

          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[2, 0], [7, 0]]])
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 0], [7, 0]]])
        })
      })

      describe('when dragging upward', function () {
        it('selects the rows between the start and end of the drag', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          runAnimationFrames()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [7, 0]]])
        })

        it('merges overlapping selections', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          runAnimationFrames()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 0], [7, 0]]])
        })
      })
    })

    describe('when the gutter is shift-clicked and dragged', function () {
      describe('when the shift-click is below the existing selection\'s tail', function () {
        describe('when dragging downward', function () {
          it('selects the rows between the existing selection\'s tail and the end of the drag', function () {
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [9, 0]])
          })
        })

        describe('when dragging upward', function () {
          it('selects the rows between the end of the drag and the tail of the existing selection', function () {
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[4, 4], [6, 0]])
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [4, 4]])
          })
        })
      })

      describe('when the shift-click is above the existing selection\'s tail', function () {
        describe('when dragging upward', function () {
          it('selects the rows between the end of the drag and the tail of the existing selection', function () {
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [4, 4]])
          })
        })

        describe('when dragging downward', function () {
          it('selects the rows between the existing selection\'s tail and the end of the drag', function () {
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [3, 4]])
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            runAnimationFrames()
            expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [9, 0]])
          })
        })
      })
    })

    describe('when soft wrap is enabled', function () {
      beforeEach(function () {
        gutterNode = componentNode.querySelector('.gutter')
        editor.setSoftWrapped(true)
        runAnimationFrames()
        componentNode.style.width = 21 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
        component.measureDimensions()
        runAnimationFrames()
      })

      describe('when the gutter is clicked', function () {
        it('selects the clicked buffer row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
          expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [2, 0]])
        })
      })

      describe('when the gutter is meta-clicked', function () {
        it('creates a new selection for the clicked buffer row', function () {
          editor.setSelectedScreenRange([[1, 0], [1, 2]])
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[1, 0], [1, 2]], [[2, 0], [5, 0]]])
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[1, 0], [1, 2]], [[2, 0], [5, 0]], [[5, 0], [10, 0]]])
        })
      })

      describe('when the gutter is shift-clicked', function () {
        beforeEach(function () {
          return editor.setSelectedScreenRange([[7, 4], [7, 6]])
        })

        describe('when the clicked row is before the current selection\'s tail', function () {
          it('selects to the beginning of the clicked buffer row', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              shiftKey: true
            }))
            expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [7, 4]])
          })
        })

        describe('when the clicked row is after the current selection\'s tail', function () {
          it('selects to the beginning of the screen row following the clicked buffer row', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), {
              shiftKey: true
            }))
            expect(editor.getSelectedScreenRange()).toEqual([[7, 4], [17, 0]])
          })
        })
      })

      describe('when the gutter is clicked and dragged', function () {
        describe('when dragging downward', function () {
          it('selects the buffer row containing the click, then screen rows until the end of the drag', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
            expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [6, 14]])
          })
        })

        describe('when dragging upward', function () {
          it('selects the buffer row containing the click, then screen rows until the end of the drag', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(1)))
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [10, 0]])
          })
        })
      })

      describe('when the gutter is meta-clicked and dragged', function () {
        beforeEach(function () {
          editor.setSelectedScreenRange([[7, 4], [7, 6]])
        })

        describe('when dragging downward', function () {
          it('adds a selection from the buffer row containing the click to the screen row containing the end of the drag', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3), {
              metaKey: true
            }))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(3), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[7, 4], [7, 6]], [[0, 0], [3, 14]]])
          })

          it('merges overlapping selections on mouseup', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7), {
              metaKey: true
            }))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(7), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [7, 12]]])
          })
        })

        describe('when dragging upward', function () {
          it('adds a selection from the buffer row containing the click to the screen row containing the end of the drag', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11), {
              metaKey: true
            }))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(11), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[7, 4], [7, 6]], [[11, 4], [20, 0]]])
          })

          it('merges overlapping selections on mouseup', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5), {
              metaKey: true
            }))
            runAnimationFrames()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(5), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[5, 0], [20, 0]]])
          })
        })
      })

      describe('when the gutter is shift-clicked and dragged', function () {
        describe('when the shift-click is below the existing selection\'s tail', function () {
          describe('when dragging downward', function () {
            it('selects the screen rows between the existing selection\'s tail and the end of the drag', function () {
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11)))
              runAnimationFrames()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [11, 5]])
            })
          })

          describe('when dragging upward', function () {
            it('selects the screen rows between the end of the drag and the tail of the existing selection', function () {
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
              runAnimationFrames()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [7, 12]])
            })
          })
        })

        describe('when the shift-click is above the existing selection\'s tail', function () {
          describe('when dragging upward', function () {
            it('selects the screen rows between the end of the drag and the tail of the existing selection', function () {
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(3), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
              runAnimationFrames()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [7, 4]])
            })
          })

          describe('when dragging downward', function () {
            it('selects the screen rows between the existing selection\'s tail and the end of the drag', function () {
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3)))
              runAnimationFrames()
              expect(editor.getSelectedScreenRange()).toEqual([[3, 2], [7, 4]])
            })
          })
        })
      })
    })
  })

  describe('focus handling', function () {
    let inputNode
    beforeEach(function () {
      inputNode = componentNode.querySelector('.hidden-input')
    })

    it('transfers focus to the hidden input', function () {
      expect(document.activeElement).toBe(document.body)
      wrapperNode.focus()
      expect(document.activeElement).toBe(inputNode)
    })

    it('adds the "is-focused" class to the editor when the hidden input is focused', function () {
      expect(document.activeElement).toBe(document.body)
      inputNode.focus()
      runAnimationFrames()

      expect(componentNode.classList.contains('is-focused')).toBe(true)
      expect(wrapperNode.classList.contains('is-focused')).toBe(true)
      inputNode.blur()
      runAnimationFrames()

      expect(componentNode.classList.contains('is-focused')).toBe(false)
      expect(wrapperNode.classList.contains('is-focused')).toBe(false)
    })
  })

  describe('selection handling', function () {
    let cursor

    beforeEach(function () {
      editor.setCursorScreenPosition([0, 0])
      runAnimationFrames()
    })

    it('adds the "has-selection" class to the editor when there is a selection', function () {
      expect(componentNode.classList.contains('has-selection')).toBe(false)
      editor.selectDown()
      runAnimationFrames()
      expect(componentNode.classList.contains('has-selection')).toBe(true)
      editor.moveDown()
      runAnimationFrames()
      expect(componentNode.classList.contains('has-selection')).toBe(false)
    })
  })

  describe('scrolling', function () {
    it('updates the vertical scrollbar when the scrollTop is changed in the model', function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()
      expect(verticalScrollbarNode.scrollTop).toBe(0)
      wrapperNode.setScrollTop(10)
      runAnimationFrames()
      expect(verticalScrollbarNode.scrollTop).toBe(10)
    })

    it('updates the horizontal scrollbar and the x transform of the lines based on the scrollLeft of the model', function () {
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()

      let top = 0
      let tilesNodes = component.tileNodesForLines()
      for (let tileNode of tilesNodes) {
        expect(tileNode.style['-webkit-transform']).toBe('translate3d(0px, ' + top + 'px, 0px)')
        top += tileNode.offsetHeight
      }
      expect(horizontalScrollbarNode.scrollLeft).toBe(0)
      wrapperNode.setScrollLeft(100)

      runAnimationFrames()

      top = 0
      for (let tileNode of tilesNodes) {
        expect(tileNode.style['-webkit-transform']).toBe('translate3d(-100px, ' + top + 'px, 0px)')
        top += tileNode.offsetHeight
      }
      expect(horizontalScrollbarNode.scrollLeft).toBe(100)
    })

    it('updates the scrollLeft of the model when the scrollLeft of the horizontal scrollbar changes', function () {
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()
      expect(wrapperNode.getScrollLeft()).toBe(0)
      horizontalScrollbarNode.scrollLeft = 100
      horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      runAnimationFrames(true)
      expect(wrapperNode.getScrollLeft()).toBe(100)
    })

    it('does not obscure the last line with the horizontal scrollbar', function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
      runAnimationFrames()

      let lastLineNode = component.lineNodeForScreenRow(editor.getLastScreenRow())
      let bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      topOfHorizontalScrollbar = horizontalScrollbarNode.getBoundingClientRect().top
      expect(bottomOfLastLine).toBe(topOfHorizontalScrollbar)
      wrapperNode.style.width = 100 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()

      bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      let bottomOfEditor = componentNode.getBoundingClientRect().bottom
      expect(bottomOfLastLine).toBe(bottomOfEditor)
    })

    it('does not obscure the last character of the longest line with the vertical scrollbar', function () {
      wrapperNode.style.height = 7 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      wrapperNode.setScrollLeft(Infinity)

      runAnimationFrames()
      let rightOfLongestLine = component.lineNodeForScreenRow(6).querySelector('.line > span:last-child').getBoundingClientRect().right
      let leftOfVerticalScrollbar = verticalScrollbarNode.getBoundingClientRect().left
      expect(Math.round(rightOfLongestLine)).toBeCloseTo(leftOfVerticalScrollbar - 1, 0)
    })

    it('only displays dummy scrollbars when scrollable in that direction', function () {
      expect(verticalScrollbarNode.style.display).toBe('none')
      expect(horizontalScrollbarNode.style.display).toBe('none')
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.display).toBe('')
      expect(horizontalScrollbarNode.style.display).toBe('none')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.display).toBe('')
      expect(horizontalScrollbarNode.style.display).toBe('')
      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.display).toBe('none')
      expect(horizontalScrollbarNode.style.display).toBe('')
    })

    it('makes the dummy scrollbar divs only as tall/wide as the actual scrollbars', function () {
      wrapperNode.style.height = 4 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      atom.styles.addStyleSheet('::-webkit-scrollbar {\n  width: 8px;\n  height: 8px;\n}', {
        context: 'atom-text-editor'
      })

      runAnimationFrames()
      runAnimationFrames()

      let scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')
      expect(verticalScrollbarNode.offsetWidth).toBe(8)
      expect(horizontalScrollbarNode.offsetHeight).toBe(8)
      expect(scrollbarCornerNode.offsetWidth).toBe(8)
      expect(scrollbarCornerNode.offsetHeight).toBe(8)
      atom.themes.removeStylesheet('test')
    })

    it('assigns the bottom/right of the scrollbars to the width of the opposite scrollbar if it is visible', function () {
      let scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')
      expect(verticalScrollbarNode.style.bottom).toBe('0px')
      expect(horizontalScrollbarNode.style.right).toBe('0px')
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.bottom).toBe('0px')
      expect(horizontalScrollbarNode.style.right).toBe(verticalScrollbarNode.offsetWidth + 'px')
      expect(scrollbarCornerNode.style.display).toBe('none')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.bottom).toBe(horizontalScrollbarNode.offsetHeight + 'px')
      expect(horizontalScrollbarNode.style.right).toBe(verticalScrollbarNode.offsetWidth + 'px')
      expect(scrollbarCornerNode.style.display).toBe('')
      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      expect(verticalScrollbarNode.style.bottom).toBe(horizontalScrollbarNode.offsetHeight + 'px')
      expect(horizontalScrollbarNode.style.right).toBe('0px')
      expect(scrollbarCornerNode.style.display).toBe('none')
    })

    it('accounts for the width of the gutter in the scrollWidth of the horizontal scrollbar', function () {
      let gutterNode = componentNode.querySelector('.gutter')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      runAnimationFrames()

      expect(horizontalScrollbarNode.scrollWidth).toBe(wrapperNode.getScrollWidth())
      expect(horizontalScrollbarNode.style.left).toBe('0px')
    })
  })

  describe('mousewheel events', function () {
    beforeEach(function () {
      editor.update({scrollSensitivity: 100})
    })

    describe('updating scrollTop and scrollLeft', function () {
      beforeEach(function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()
      })

      it('updates the scrollLeft or scrollTop on mousewheel events depending on which delta is greater (x or y)', function () {
        expect(verticalScrollbarNode.scrollTop).toBe(0)
        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -5,
          wheelDeltaY: -10
        }))
        runAnimationFrames()

        expect(verticalScrollbarNode.scrollTop).toBe(10)
        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -15,
          wheelDeltaY: -5
        }))
        runAnimationFrames()

        expect(verticalScrollbarNode.scrollTop).toBe(10)
        expect(horizontalScrollbarNode.scrollLeft).toBe(15)
      })

      it('updates the scrollLeft or scrollTop according to the scroll sensitivity', function () {
        editor.update({scrollSensitivity: 50})
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -5,
          wheelDeltaY: -10
        }))
        runAnimationFrames()

        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -15,
          wheelDeltaY: -5
        }))
        runAnimationFrames()

        expect(verticalScrollbarNode.scrollTop).toBe(5)
        expect(horizontalScrollbarNode.scrollLeft).toBe(7)
      })
    })

    describe('when the mousewheel event\'s target is a line', function () {
      it('keeps the line on the DOM if it is scrolled off-screen', function () {
        component.presenter.stoppedScrollingDelay = 3000 // account for slower build machines
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        runAnimationFrames()

        expect(componentNode.contains(lineNode)).toBe(true)
      })

      it('does not set the mouseWheelScreenRow if scrolling horizontally', function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 10,
          wheelDeltaY: 0
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        runAnimationFrames()

        expect(component.presenter.mouseWheelScreenRow).toBe(null)
      })

      it('clears the mouseWheelScreenRow after a delay even if the event does not cause scrolling', async function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: 10
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(component.presenter.mouseWheelScreenRow).toBe(0)

        advanceClock(component.presenter.stoppedScrollingDelay)
        expect(component.presenter.mouseWheelScreenRow).toBeNull()
      })

      it('does not preserve the line if it is on screen', function () {
        let lineNode, lineNodes, wheelEvent
        expect(componentNode.querySelectorAll('.line-number').length).toBe(14)
        lineNodes = componentNode.querySelectorAll('.line')
        expect(lineNodes.length).toBe(13)
        lineNode = lineNodes[0]
        wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: 100
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        expect(component.presenter.mouseWheelScreenRow).toBe(0)
        editor.insertText('hello')
        expect(componentNode.querySelectorAll('.line-number').length).toBe(14)
        expect(componentNode.querySelectorAll('.line').length).toBe(13)
      })
    })

    describe('when the mousewheel event\'s target is a line number', function () {
      it('keeps the line number on the DOM if it is scrolled off-screen', function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let lineNumberNode = componentNode.querySelectorAll('.line-number')[1]
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNumberNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        runAnimationFrames()

        expect(componentNode.contains(lineNumberNode)).toBe(true)
      })
    })

    describe('when the mousewheel event\'s target is a block decoration', function () {
      it('keeps it on the DOM if it is scrolled off-screen', function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        let item = document.createElement("div")
        item.style.width = "30px"
        item.style.height = "30px"
        item.className = "decoration-1"
        editor.decorateMarker(
          editor.markScreenPosition([0, 0], {invalidate: "never"}),
          {type: "block", item: item}
        )

        runAnimationFrames()

        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return item
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        runAnimationFrames()

        expect(component.getTopmostDOMNode().contains(item)).toBe(true)
      })
    })

    describe('when the mousewheel event\'s target is an SVG element inside a block decoration', function () {
      it('keeps the block decoration on the DOM if it is scrolled off-screen', function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()

        const item = document.createElement('div')
        const svgElement = document.createElementNS("http://www.w3.org/2000/svg", "svg")
        item.appendChild(svgElement)
        editor.decorateMarker(
          editor.markScreenPosition([0, 0], {invalidate: "never"}),
          {type: "block", item: item}
        )

        runAnimationFrames()

        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return svgElement
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        runAnimationFrames()

        expect(component.getTopmostDOMNode().contains(item)).toBe(true)
      })
    })

    it('only prevents the default action of the mousewheel event if it actually lead to scrolling', function () {
      spyOn(WheelEvent.prototype, 'preventDefault').andCallThrough()
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * charWidth + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: 50
      }))
      expect(wrapperNode.getScrollTop()).toBe(0)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: -3000
      }))
      runAnimationFrames()

      let maxScrollTop = wrapperNode.getScrollTop()
      expect(WheelEvent.prototype.preventDefault).toHaveBeenCalled()
      WheelEvent.prototype.preventDefault.reset()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: -30
      }))
      expect(wrapperNode.getScrollTop()).toBe(maxScrollTop)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 50,
        wheelDeltaY: 0
      }))
      expect(wrapperNode.getScrollLeft()).toBe(0)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: -3000,
        wheelDeltaY: 0
      }))
      runAnimationFrames()

      let maxScrollLeft = wrapperNode.getScrollLeft()
      expect(WheelEvent.prototype.preventDefault).toHaveBeenCalled()
      WheelEvent.prototype.preventDefault.reset()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: -30,
        wheelDeltaY: 0
      }))
      expect(wrapperNode.getScrollLeft()).toBe(maxScrollLeft)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
    })
  })

  describe('input events', function () {
    function buildTextInputEvent ({data, target}) {
      let event = new Event('textInput')
      event.data = data
      Object.defineProperty(event, 'target', {
        get: function () {
          return target
        }
      })
      return event
    }

    function buildKeydownEvent ({keyCode, target}) {
      let event = new KeyboardEvent('keydown')
      Object.defineProperty(event, 'keyCode', {
        get: function () {
          return keyCode
        }
      })
      Object.defineProperty(event, 'target', {
        get: function () {
          return target
        }
      })
      return event
    }

    let inputNode

    beforeEach(function () {
      inputNode = componentNode.querySelector('.hidden-input')
    })

    it('inserts the newest character in the input\'s value into the buffer', function () {
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      runAnimationFrames()

      expect(editor.lineTextForBufferRow(0)).toBe('xvar quicksort = function () {')
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'y',
        target: inputNode
      }))

      expect(editor.lineTextForBufferRow(0)).toBe('xyvar quicksort = function () {')
    })

    it('replaces the last character if a keypress event is bracketed by keydown events with matching keyCodes, which occurs when the accented character menu is shown', function () {
      componentNode.dispatchEvent(buildKeydownEvent({keyCode: 85, target: inputNode}))
      componentNode.dispatchEvent(buildTextInputEvent({data: 'u', target: inputNode}))
      componentNode.dispatchEvent(new KeyboardEvent('keypress'))
      componentNode.dispatchEvent(buildKeydownEvent({keyCode: 85, target: inputNode}))
      componentNode.dispatchEvent(new KeyboardEvent('keyup'))
      runAnimationFrames()

      expect(editor.lineTextForBufferRow(0)).toBe('uvar quicksort = function () {')
      inputNode.setSelectionRange(0, 1)
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'ü',
        target: inputNode
      }))
      runAnimationFrames()

      expect(editor.lineTextForBufferRow(0)).toBe('üvar quicksort = function () {')
    })

    it('does not handle input events when input is disabled', function () {
      component.setInputEnabled(false)
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
      runAnimationFrames()
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
    })

    it('groups events that occur close together in time into single undo entries', function () {
      let currentTime = 0
      spyOn(Date, 'now').andCallFake(function () {
        return currentTime
      })
      editor.update({undoGroupingInterval: 100})
      editor.setText('')
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      currentTime += 99
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'y',
        target: inputNode
      }))
      currentTime += 99
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', {
        bubbles: true,
        cancelable: true
      }))
      currentTime += 101
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('xy\nxy\nxy')
      componentNode.dispatchEvent(new CustomEvent('core:undo', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('xy\nxy')
      componentNode.dispatchEvent(new CustomEvent('core:undo', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('')
    })

    describe('when IME composition is used to insert international characters', function () {
      function buildIMECompositionEvent (event, {data, target} = {}) {
        event = new Event(event)
        event.data = data
        Object.defineProperty(event, 'target', {
          get: function () {
            return target
          }
        })
        return event
      }

      let inputNode

      beforeEach(function () {
        inputNode = componentNode.querySelector('.hidden-input')
      })

      describe('when nothing is selected', function () {
        it('inserts the chosen completion', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('svar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('sdvar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: '速度',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('速度var quicksort = function () {')
        })

        it('reverts back to the original text when the completion helper is dismissed', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('svar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('sdvar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
        })

        it('allows multiple accented character to be inserted with the \' on a US international layout', function () {
          inputNode.value = '\''
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: '\'',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('\'var quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: 'á',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('ávar quicksort = function () {')
          inputNode.value = '\''
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: '\'',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('á\'var quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: 'á',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('áávar quicksort = function () {')
        })
      })

      describe('when a string is selected', function () {
        beforeEach(function () {
          editor.setSelectedBufferRanges([[[0, 4], [0, 9]], [[0, 16], [0, 19]]])
        })

        it('inserts the chosen completion', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var ssort = sction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var sdsort = sdction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: '速度',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var 速度sort = 速度ction () {')
        })

        it('reverts back to the original text when the completion helper is dismissed', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var ssort = sction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var sdsort = sdction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
        })
      })
    })
  })

  describe('commands', function () {
    describe('editor:consolidate-selections', function () {
      it('consolidates selections on the editor model, aborting the key binding if there is only one selection', function () {
        spyOn(editor, 'consolidateSelections').andCallThrough()
        let event = new CustomEvent('editor:consolidate-selections', {
          bubbles: true,
          cancelable: true
        })
        event.abortKeyBinding = jasmine.createSpy('event.abortKeyBinding')
        componentNode.dispatchEvent(event)
        expect(editor.consolidateSelections).toHaveBeenCalled()
        expect(event.abortKeyBinding).toHaveBeenCalled()
      })
    })
  })

  describe('when decreasing the fontSize', function () {
    it('decreases the widths of the korean char, the double width char and the half width char', function () {
      originalDefaultCharWidth = editor.getDefaultCharWidth()
      koreanDefaultCharWidth = editor.getKoreanCharWidth()
      doubleWidthDefaultCharWidth = editor.getDoubleWidthCharWidth()
      halfWidthDefaultCharWidth = editor.getHalfWidthCharWidth()
      component.setFontSize(10)
      runAnimationFrames()
      expect(editor.getDefaultCharWidth()).toBeLessThan(originalDefaultCharWidth)
      expect(editor.getKoreanCharWidth()).toBeLessThan(koreanDefaultCharWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeLessThan(doubleWidthDefaultCharWidth)
      expect(editor.getHalfWidthCharWidth()).toBeLessThan(halfWidthDefaultCharWidth)
    })
  })

  describe('when increasing the fontSize', function() {
    it('increases the widths of the korean char, the double width char and the half width char', function () {
      originalDefaultCharWidth = editor.getDefaultCharWidth()
      koreanDefaultCharWidth = editor.getKoreanCharWidth()
      doubleWidthDefaultCharWidth = editor.getDoubleWidthCharWidth()
      halfWidthDefaultCharWidth = editor.getHalfWidthCharWidth()
      component.setFontSize(25)
      runAnimationFrames()
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(originalDefaultCharWidth)
      expect(editor.getKoreanCharWidth()).toBeGreaterThan(koreanDefaultCharWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeGreaterThan(doubleWidthDefaultCharWidth)
      expect(editor.getHalfWidthCharWidth()).toBeGreaterThan(halfWidthDefaultCharWidth)
    })
  })

  describe('hiding and showing the editor', function () {
    describe('when the editor is hidden when it is mounted', function () {
      it('defers measurement and rendering until the editor becomes visible', function () {
        wrapperNode.remove()
        let hiddenParent = document.createElement('div')
        hiddenParent.style.display = 'none'
        contentNode.appendChild(hiddenParent)
        wrapperNode = new TextEditorElement()
        wrapperNode.tileSize = TILE_SIZE
        wrapperNode.initialize(editor, atom)
        hiddenParent.appendChild(wrapperNode)
        component = wrapperNode.component
        componentNode = component.getDomNode()
        expect(componentNode.querySelectorAll('.line').length).toBe(0)
        hiddenParent.style.display = 'block'
        atom.views.performDocumentPoll()
        expect(componentNode.querySelectorAll('.line').length).toBeGreaterThan(0)
      })
    })

    describe('when the lineHeight changes while the editor is hidden', function () {
      it('does not attempt to measure the lineHeightInPixels until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        component.setLineHeight(2)
        expect(editor.getLineHeightInPixels()).toBe(initialLineHeightInPixels)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeightInPixels)
      })
    })

    describe('when the fontSize changes while the editor is hidden', function () {
      it('does not attempt to measure the lineHeightInPixels or defaultCharWidth until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        let initialCharWidth = editor.getDefaultCharWidth()
        component.setFontSize(22)
        expect(editor.getLineHeightInPixels()).toBe(initialLineHeightInPixels)
        expect(editor.getDefaultCharWidth()).toBe(initialCharWidth)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeightInPixels)
        expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
      })

      it('does not re-measure character widths until the editor is shown again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        component.setFontSize(22)
        editor.getBuffer().insert([0, 0], 'a')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        runAnimationFrames()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })

    describe('when the fontFamily changes while the editor is hidden', function () {
      it('does not attempt to measure the defaultCharWidth until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        let initialCharWidth = editor.getDefaultCharWidth()
        component.setFontFamily('serif')
        expect(editor.getDefaultCharWidth()).toBe(initialCharWidth)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
      })

      it('does not re-measure character widths until the editor is shown again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        component.setFontFamily('serif')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        runAnimationFrames()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })

    describe('when stylesheets change while the editor is hidden', function () {
      afterEach(function () {
        atom.themes.removeStylesheet('test')
      })

      it('does not re-measure character widths until the editor is shown again', function () {
        atom.config.set('editor.fontFamily', 'sans-serif')
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        atom.themes.applyStylesheet('test', '.syntax--function.syntax--js {\n  font-weight: bold;\n}')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        runAnimationFrames()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })
  })

  describe('soft wrapping', function () {
    beforeEach(function () {
      editor.setSoftWrapped(true)
      runAnimationFrames()
    })

    it('updates the wrap location when the editor is resized', function () {
      let newHeight = 4 * editor.getLineHeightInPixels() + 'px'
      expect(parseInt(newHeight)).toBeLessThan(wrapperNode.offsetHeight)
      wrapperNode.style.height = newHeight
      editor.update({autoHeight: false})
      atom.views.performDocumentPoll()
      runAnimationFrames()

      expect(componentNode.querySelectorAll('.line')).toHaveLength(7)
      let gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      componentNode.style.width = gutterWidth + 14 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
      atom.views.performDocumentPoll()
      runAnimationFrames()
      expect(componentNode.querySelector('.line').textContent).toBe('var quicksort ')
    })

    it('accounts for the scroll view\'s padding when determining the wrap location', function () {
      let scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewNode.style.paddingLeft = 20 + 'px'
      componentNode.style.width = 30 * charWidth + 'px'
      atom.views.performDocumentPoll()
      runAnimationFrames()
      expect(component.lineNodeForScreenRow(0).textContent).toBe('var quicksort = ')
    })
  })

  describe('default decorations', function () {
    it('applies .cursor-line decorations for line numbers overlapping selections', function () {
      editor.setCursorScreenPosition([4, 4])
      runAnimationFrames()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(false)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(5, 'cursor-line')).toBe(false)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      runAnimationFrames()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      editor.setSelectedScreenRange([[3, 4], [4, 0]])
      runAnimationFrames()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(false)
    })

    it('does not apply .cursor-line to the last line of a selection if it\'s empty', function () {
      editor.setSelectedScreenRange([[3, 4], [5, 0]])
      runAnimationFrames()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(5, 'cursor-line')).toBe(false)
    })

    it('applies .cursor-line decorations for lines containing the cursor in non-empty selections', function () {
      editor.setCursorScreenPosition([4, 4])
      runAnimationFrames()

      expect(lineHasClass(3, 'cursor-line')).toBe(false)
      expect(lineHasClass(4, 'cursor-line')).toBe(true)
      expect(lineHasClass(5, 'cursor-line')).toBe(false)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      runAnimationFrames()

      expect(lineHasClass(2, 'cursor-line')).toBe(false)
      expect(lineHasClass(3, 'cursor-line')).toBe(false)
      expect(lineHasClass(4, 'cursor-line')).toBe(false)
      expect(lineHasClass(5, 'cursor-line')).toBe(false)
    })

    it('applies .cursor-line-no-selection to line numbers for rows containing the cursor when the selection is empty', function () {
      editor.setCursorScreenPosition([4, 4])
      runAnimationFrames()

      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe(true)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      runAnimationFrames()

      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe(false)
    })
  })

  describe('height', function () {
    describe('when autoHeight is true', function () {
      it('assigns the editor\'s height to based on its contents', function () {
        jasmine.attachToDOM(wrapperNode)
        expect(editor.getAutoHeight()).toBe(true)
        expect(wrapperNode.offsetHeight).toBe(editor.getLineHeightInPixels() * editor.getScreenLineCount())
        editor.insertText('\n\n\n')
        runAnimationFrames()
        expect(wrapperNode.offsetHeight).toBe(editor.getLineHeightInPixels() * editor.getScreenLineCount())
      })
    })

    describe('when autoHeight is false', function () {
      it('does not assign the height of the editor, instead allowing content to scroll', function () {
        jasmine.attachToDOM(wrapperNode)
        editor.update({autoHeight: false})
        wrapperNode.style.height = '200px'
        expect(wrapperNode.offsetHeight).toBe(200)
        editor.insertText('\n\n\n')
        runAnimationFrames()
        expect(wrapperNode.offsetHeight).toBe(200)
      })
    })

    describe('when autoHeight is not assigned on the editor', function () {
      it('implicitly assigns autoHeight to true and emits a deprecation warning if the editor has its height assigned via an inline style', function () {
        editor = new TextEditor()
        element = editor.getElement()
        element.setUpdatedSynchronously(false)
        element.style.height = '200px'

        spyOn(Grim, 'deprecate')
        jasmine.attachToDOM(element)

        expect(element.offsetHeight).toBe(200)
        expect(element.querySelector('.editor-contents--private').offsetHeight).toBe(200)
        expect(Grim.deprecate.callCount).toBe(1)
        expect(Grim.deprecate.argsForCall[0][0]).toMatch(/inline style/)
      })

      it('implicitly assigns autoHeight to true and emits a deprecation warning if the editor has its height assigned via position absolute with an assigned top and bottom', function () {
        editor = new TextEditor()
        element = editor.getElement()
        element.setUpdatedSynchronously(false)
        parentElement = document.createElement('div')
        parentElement.style.position = 'absolute'
        parentElement.style.height = '200px'
        element.style.position = 'absolute'
        element.style.top = '0px'
        element.style.bottom = '0px'
        parentElement.appendChild(element)

        spyOn(Grim, 'deprecate')

        jasmine.attachToDOM(parentElement)
        element.component.measureDimensions()

        expect(element.offsetHeight).toBe(200)
        expect(element.querySelector('.editor-contents--private').offsetHeight).toBe(200)
        expect(Grim.deprecate.callCount).toBe(1)
        expect(Grim.deprecate.argsForCall[0][0]).toMatch(/absolute/)
      })
    })

    describe('when the wrapper view has an explicit height', function () {
      it('does not assign a height on the component node', function () {
        wrapperNode.style.height = '200px'
        editor.update({autoHeight: false})
        component.measureDimensions()
        runAnimationFrames()
        expect(componentNode.style.height).toBe('')
      })
    })

    describe('when the wrapper view does not have an explicit height', function () {
      it('assigns a height on the component node based on the editor\'s content', function () {
        expect(wrapperNode.style.height).toBe('')
        expect(componentNode.style.height).toBe(editor.getScreenLineCount() * lineHeightInPixels + 'px')
      })
    })
  })

  describe('width', function () {
    it('sizes the editor element according to the content width when auto width is true, or according to the container width otherwise', function () {
      contentNode.style.width = '600px'
      component.measureDimensions()
      editor.setText("abcdefghi")
      runAnimationFrames()
      expect(wrapperNode.offsetWidth).toBe(contentNode.offsetWidth)

      editor.update({autoWidth: true})
      runAnimationFrames()
      const editorWidth1 = wrapperNode.offsetWidth
      expect(editorWidth1).toBeGreaterThan(0)
      expect(editorWidth1).toBeLessThan(contentNode.offsetWidth)

      editor.setText("abcdefghijkl")
      editor.update({autoWidth: true})
      runAnimationFrames()
      const editorWidth2 = wrapperNode.offsetWidth
      expect(editorWidth2).toBeGreaterThan(editorWidth1)
      expect(editorWidth2).toBeLessThan(contentNode.offsetWidth)

      editor.update({autoWidth: false})
      runAnimationFrames()
      expect(wrapperNode.offsetWidth).toBe(contentNode.offsetWidth)
    })
  })

  describe('when the "mini" property is true', function () {
    beforeEach(function () {
      editor.setMini(true)
      runAnimationFrames()
    })

    it('does not render the gutter', function () {
      expect(componentNode.querySelector('.gutter')).toBeNull()
    })

    it('adds the "mini" class to the wrapper view', function () {
      expect(wrapperNode.classList.contains('mini')).toBe(true)
    })

    it('does not have an opaque background on lines', function () {
      expect(component.linesComponent.getDomNode().getAttribute('style')).not.toContain('background-color')
    })

    it('does not render invisible characters', function () {
      editor.update({
        showInvisibles: true,
        invisibles: {eol: 'E'}
      })
      expect(component.lineNodeForScreenRow(0).textContent).toBe('var quicksort = function () {')
    })

    it('does not assign an explicit line-height on the editor contents', function () {
      expect(componentNode.style.lineHeight).toBe('')
    })

    it('does not apply cursor-line decorations', function () {
      expect(component.lineNodeForScreenRow(0).classList.contains('cursor-line')).toBe(false)
    })
  })

  describe('when placholderText is specified', function () {
    it('renders the placeholder text when the buffer is empty', function () {
      editor.setPlaceholderText('Hello World')
      expect(componentNode.querySelector('.placeholder-text')).toBeNull()
      editor.setText('')
      runAnimationFrames()

      expect(componentNode.querySelector('.placeholder-text').textContent).toBe('Hello World')
      editor.setText('hey')
      runAnimationFrames()

      expect(componentNode.querySelector('.placeholder-text')).toBeNull()
    })
  })

  describe('grammar data attributes', function () {
    it('adds and updates the grammar data attribute based on the current grammar', function () {
      expect(wrapperNode.dataset.grammar).toBe('source js')
      editor.setGrammar(atom.grammars.nullGrammar)
      expect(wrapperNode.dataset.grammar).toBe('text plain null-grammar')
    })
  })

  describe('encoding data attributes', function () {
    it('adds and updates the encoding data attribute based on the current encoding', function () {
      expect(wrapperNode.dataset.encoding).toBe('utf8')
      editor.setEncoding('utf16le')
      expect(wrapperNode.dataset.encoding).toBe('utf16le')
    })
  })

  describe('detaching and reattaching the editor (regression)', function () {
    it('does not throw an exception', function () {
      wrapperNode.remove()
      jasmine.attachToDOM(wrapperNode)
      atom.commands.dispatch(wrapperNode, 'core:move-right')
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])
    })
  })

  describe('autoscroll', function () {
    beforeEach(function () {
      editor.setVerticalScrollMargin(2)
      editor.setHorizontalScrollMargin(2)
      component.setLineHeight('10px')
      component.setFontSize(17)
      component.measureDimensions()
      runAnimationFrames()

      wrapperNode.style.width = 55 + component.getGutterWidth() + 'px'
      wrapperNode.style.height = '55px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      component.presenter.setHorizontalScrollbarHeight(0)
      component.presenter.setVerticalScrollbarWidth(0)
      runAnimationFrames()
    })

    describe('when selecting buffer ranges', function () {
      it('autoscrolls the selection if it is last unless the "autoscroll" option is false', function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedBufferRange([[5, 6], [6, 8]])
        runAnimationFrames()

        let right = wrapperNode.pixelPositionForBufferPosition([6, 8 + editor.getHorizontalScrollMargin()]).left
        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        editor.setSelectedBufferRange([[0, 0], [0, 0]])
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)
        editor.setSelectedBufferRange([[6, 6], [6, 8]])
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
      })
    })

    describe('when adding selections for buffer ranges', function () {
      it('autoscrolls to the added selection if needed', function () {
        editor.addSelectionForBufferRange([[8, 10], [8, 15]])
        runAnimationFrames()

        let right = wrapperNode.pixelPositionForBufferPosition([8, 15]).left
        expect(wrapperNode.getScrollBottom()).toBe((9 * 10) + (2 * 10))
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right + 2 * 10, 0)
      })
    })

    describe('when selecting lines containing cursors', function () {
      it('autoscrolls to the selection', function () {
        editor.setCursorScreenPosition([5, 6])
        runAnimationFrames()

        wrapperNode.scrollToTop()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.selectLinesContainingCursors()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
      })
    })

    describe('when inserting text', function () {
      describe('when there are multiple empty selections on different lines', function () {
        it('autoscrolls to the last cursor', function () {
          editor.setCursorScreenPosition([1, 2], {
            autoscroll: false
          })
          runAnimationFrames()

          editor.addCursorAtScreenPosition([10, 4], {
            autoscroll: false
          })
          runAnimationFrames()

          expect(wrapperNode.getScrollTop()).toBe(0)
          editor.insertText('a')
          runAnimationFrames()

          expect(wrapperNode.getScrollTop()).toBe(75)
        })
      })
    })

    describe('when scrolled to cursor position', function () {
      it('scrolls the last cursor into view, centering around the cursor if possible and the "center" option is not false', function () {
        editor.setCursorScreenPosition([8, 8], {
          autoscroll: false
        })
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)
        editor.scrollToCursorPosition()
        runAnimationFrames()

        let right = wrapperNode.pixelPositionForScreenPosition([8, 9 + editor.getHorizontalScrollMargin()]).left
        expect(wrapperNode.getScrollTop()).toBe((8.8 * 10) - 30)
        expect(wrapperNode.getScrollBottom()).toBe((8.3 * 10) + 30)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        wrapperNode.setScrollTop(0)
        editor.scrollToCursorPosition({
          center: false
        })
        expect(wrapperNode.getScrollTop()).toBe((7.8 - editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollBottom()).toBe((9.3 + editor.getVerticalScrollMargin()) * 10)
      })
    })

    describe('moving cursors', function () {
      it('scrolls down when the last cursor gets closer than ::verticalScrollMargin to the bottom of the editor', function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollBottom()).toBe(5.5 * 10)
        editor.setCursorScreenPosition([2, 0])
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(5.5 * 10)
        editor.moveDown()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(6 * 10)
        editor.moveDown()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(7 * 10)
      })

      it('scrolls up when the last cursor gets closer than ::verticalScrollMargin to the top of the editor', function () {
        editor.setCursorScreenPosition([11, 0])
        runAnimationFrames()

        wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
        runAnimationFrames()

        editor.moveUp()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(wrapperNode.getScrollHeight())
        editor.moveUp()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(7 * 10)
        editor.moveUp()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(6 * 10)
      })

      it('scrolls right when the last cursor gets closer than ::horizontalScrollMargin to the right of the editor', function () {
        expect(wrapperNode.getScrollLeft()).toBe(0)
        expect(wrapperNode.getScrollRight()).toBe(5.5 * 10)
        editor.setCursorScreenPosition([0, 2])
        runAnimationFrames()

        expect(wrapperNode.getScrollRight()).toBe(5.5 * 10)
        editor.moveRight()
        runAnimationFrames()

        let margin = component.presenter.getHorizontalScrollMarginInPixels()
        let right = wrapperNode.pixelPositionForScreenPosition([0, 4]).left + margin
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        editor.moveRight()
        runAnimationFrames()

        right = wrapperNode.pixelPositionForScreenPosition([0, 5]).left + margin
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
      })

      it('scrolls left when the last cursor gets closer than ::horizontalScrollMargin to the left of the editor', function () {
        wrapperNode.setScrollRight(wrapperNode.getScrollWidth())
        runAnimationFrames()

        expect(wrapperNode.getScrollRight()).toBe(wrapperNode.getScrollWidth())
        editor.setCursorScreenPosition([6, 62], {
          autoscroll: false
        })
        runAnimationFrames()

        editor.moveLeft()
        runAnimationFrames()

        let margin = component.presenter.getHorizontalScrollMarginInPixels()
        let left = wrapperNode.pixelPositionForScreenPosition([6, 61]).left - margin
        expect(wrapperNode.getScrollLeft()).toBeCloseTo(left, 0)
        editor.moveLeft()
        runAnimationFrames()

        left = wrapperNode.pixelPositionForScreenPosition([6, 60]).left - margin
        expect(wrapperNode.getScrollLeft()).toBeCloseTo(left, 0)
      })

      it('scrolls down when inserting lines makes the document longer than the editor\'s height', function () {
        editor.setCursorScreenPosition([13, Infinity])
        editor.insertNewline()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(14 * 10)
        editor.insertNewline()
        runAnimationFrames()

        expect(wrapperNode.getScrollBottom()).toBe(15 * 10)
      })

      it('autoscrolls to the cursor when it moves due to undo', function () {
        editor.insertText('abc')
        wrapperNode.setScrollTop(Infinity)
        runAnimationFrames()

        editor.undo()
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
      })

      it('does not scroll when the cursor moves into the visible area', function () {
        editor.setCursorBufferPosition([0, 0])
        runAnimationFrames()

        wrapperNode.setScrollTop(40)
        runAnimationFrames()

        editor.setCursorBufferPosition([6, 0])
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(40)
      })

      it('honors the autoscroll option on cursor and selection manipulation methods', function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addCursorAtScreenPosition([11, 11], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addCursorAtBufferPosition([11, 11], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setCursorScreenPosition([11, 11], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setCursorBufferPosition([11, 11], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForBufferRange([[11, 11], [11, 11]], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForScreenRange([[11, 11], [11, 12]], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedBufferRange([[11, 0], [11, 1]], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedScreenRange([[11, 0], [11, 6]], {autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.clearSelections({autoscroll: false})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForScreenRange([[0, 0], [0, 4]])
        runAnimationFrames()

        editor.getCursors()[0].setScreenPosition([11, 11], {autoscroll: true})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        editor.getCursors()[0].setBufferPosition([0, 0], {autoscroll: true})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.getSelections()[0].setScreenRange([[11, 0], [11, 4]], {autoscroll: true})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        editor.getSelections()[0].setBufferRange([[0, 0], [0, 4]], {autoscroll: true})
        runAnimationFrames()

        expect(wrapperNode.getScrollTop()).toBe(0)
      })
    })
  })

  describe('::getVisibleRowRange()', function () {
    beforeEach(function () {
      wrapperNode.style.height = lineHeightInPixels * 8 + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()
    })

    it('returns the first and the last visible rows', function () {
      component.setScrollTop(0)
      runAnimationFrames()
      expect(component.getVisibleRowRange()).toEqual([0, 9])
    })

    it('ends at last buffer row even if there\'s more space available', function () {
      wrapperNode.style.height = lineHeightInPixels * 13 + 'px'
      editor.update({autoHeight: false})
      component.measureDimensions()
      runAnimationFrames()

      component.setScrollTop(60)
      runAnimationFrames()

      expect(component.getVisibleRowRange()).toEqual([0, 13])
    })
  })

  describe('::pixelPositionForScreenPosition()', () => {
    it('returns the correct horizontal position, even if it is on a row that has not yet been rendered (regression)', () => {
      editor.setTextInBufferRange([[5, 0], [6, 0]], 'hello world\n')
      expect(wrapperNode.pixelPositionForScreenPosition([5, Infinity]).left).toBeGreaterThan(0)
    })
  })

  describe('middle mouse paste on Linux', function () {
    let originalPlatform

    beforeEach(function () {
      originalPlatform = process.platform
      Object.defineProperty(process, 'platform', {
        value: 'linux'
      })
    })

    afterEach(function () {
      Object.defineProperty(process, 'platform', {
        value: originalPlatform
      })
    })

    it('pastes the previously selected text at the clicked location', async function () {
      let clipboardWrittenTo = false
      spyOn(require('electron').ipcRenderer, 'send').andCallFake(function (eventName, selectedText) {
        if (eventName === 'write-text-to-selection-clipboard') {
          require('../src/safe-clipboard').writeText(selectedText, 'selection')
          clipboardWrittenTo = true
        }
      })
      atom.clipboard.write('')
      component.trackSelectionClipboard()
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      advanceClock(0)

      componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([10, 0]), {
        button: 1
      }))
      componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([10, 0]), {
        which: 2
      }))
      expect(atom.clipboard.read()).toBe('sort')
      expect(editor.lineTextForBufferRow(10)).toBe('sort')
    })
  })

  function buildMouseEvent (type, ...propertiesObjects) {
    let properties = extend({
      bubbles: true,
      cancelable: true
    }, ...propertiesObjects)

    if (properties.detail == null) {
      properties.detail = 1
    }

    let event = new MouseEvent(type, properties)
    if (properties.which != null) {
      Object.defineProperty(event, 'which', {
        get: function () {
          return properties.which
        }
      })
    }
    if (properties.target != null) {
      Object.defineProperty(event, 'target', {
        get: function () {
          return properties.target
        }
      })
      Object.defineProperty(event, 'srcObject', {
        get: function () {
          return properties.target
        }
      })
    }
    return event
  }

  function clientCoordinatesForScreenPosition (screenPosition) {
    let clientX, clientY, positionOffset, scrollViewClientRect
    positionOffset = wrapperNode.pixelPositionForScreenPosition(screenPosition)
    scrollViewClientRect = componentNode.querySelector('.scroll-view').getBoundingClientRect()
    clientX = scrollViewClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = scrollViewClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    return {
      clientX: clientX,
      clientY: clientY
    }
  }

  function clientCoordinatesForScreenRowInGutter (screenRow) {
    let clientX, clientY, gutterClientRect, positionOffset
    positionOffset = wrapperNode.pixelPositionForScreenPosition([screenRow, Infinity])
    gutterClientRect = componentNode.querySelector('.gutter').getBoundingClientRect()
    clientX = gutterClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = gutterClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    return {
      clientX: clientX,
      clientY: clientY
    }
  }

  function lineAndLineNumberHaveClass (screenRow, klass) {
    return lineHasClass(screenRow, klass) && lineNumberHasClass(screenRow, klass)
  }

  function lineNumberHasClass (screenRow, klass) {
    return component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function lineNumberForBufferRowHasClass (bufferRow, klass) {
    let screenRow
    screenRow = editor.screenRowForBufferRow(bufferRow)
    return component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function lineHasClass (screenRow, klass) {
    return component.lineNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function getLeafNodes (node) {
    if (node.children.length > 0) {
      return flatten(toArray(node.children).map(getLeafNodes))
    } else {
      return [node]
    }
  }

  function conditionPromise (condition)  {
    let timeoutError = new Error("Timed out waiting on condition")
    Error.captureStackTrace(timeoutError, conditionPromise)

    return new Promise(function (resolve, reject) {
      let interval = window.setInterval.originalValue.apply(window, [function () {
        if (condition()) {
          window.clearInterval(interval)
          window.clearTimeout(timeout)
          resolve()
        }
      }, 100])
      let timeout = window.setTimeout.originalValue.apply(window, [function () {
        window.clearInterval(interval)
        reject(timeoutError)
      }, 5000])
    })
  }

  function decorationsUpdatedPromise(editor) {
    return new Promise(function (resolve) {
      let disposable = editor.onDidUpdateDecorations(function () {
        disposable.dispose()
        resolve()
      })
    })
  }
})
