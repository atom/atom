/** @babel */

import TokenizedBufferIterator from '../src/tokenized-buffer-iterator'
import {Point} from 'text-buffer'

describe('TokenizedBufferIterator', () => {
  it('reports two boundaries at the same position when tags close, open, then close again without a non-negative integer separating them (regression)', () => {
    const tokenizedBuffer = {
      tokenizedLineForRow () {
        return {
          tags: [-1, -2, -1, -2],
          text: '',
          openScopes: []
        }
      }
    }

    const grammarRegistry = {
      scopeForId () {
        return 'foo'
      }
    }

    const iterator = new TokenizedBufferIterator(tokenizedBuffer, grammarRegistry)

    iterator.seek(Point(0, 0))
    expect(iterator.getPosition()).toEqual(Point(0, 0))
    expect(iterator.getCloseTags()).toEqual([])
    expect(iterator.getOpenTags()).toEqual(['foo'])

    iterator.moveToSuccessor()
    expect(iterator.getPosition()).toEqual(Point(0, 0))
    expect(iterator.getCloseTags()).toEqual(['foo'])
    expect(iterator.getOpenTags()).toEqual(['foo'])

    iterator.moveToSuccessor()
    expect(iterator.getCloseTags()).toEqual(['foo'])
    expect(iterator.getOpenTags()).toEqual([])
  })

  it("reports a boundary at line end if the next line's open scopes don't match the containing tags for the current line", () => {
    const tokenizedBuffer = {
      tokenizedLineForRow (row) {
        if (row === 0) {
          return {
            tags: [-1, 3, -2, -3],
            text: 'bar',
            openScopes: []
          }
        } else if (row === 1) {
          return {
            tags: [3],
            text: 'baz',
            openScopes: [-1]
          }
        } else if (row === 2) {
          return {
            tags: [-2],
            text: '',
            openScopes: [-1]
          }
        }
      }
    }

    const grammarRegistry = {
      scopeForId (id) {
        if (id === -2 || id === -1) {
          return 'foo'
        } else if (id === -3) {
          return 'qux'
        }
      }
    }

    const iterator = new TokenizedBufferIterator(tokenizedBuffer, grammarRegistry)

    iterator.seek(Point(0, 0))
    expect(iterator.getPosition()).toEqual(Point(0, 0))
    expect(iterator.getCloseTags()).toEqual([])
    expect(iterator.getOpenTags()).toEqual(['foo'])

    iterator.moveToSuccessor()
    expect(iterator.getPosition()).toEqual(Point(0, 3))
    expect(iterator.getCloseTags()).toEqual(['foo'])
    expect(iterator.getOpenTags()).toEqual(['qux'])

    iterator.moveToSuccessor()
    expect(iterator.getPosition()).toEqual(Point(0, 3))
    expect(iterator.getCloseTags()).toEqual(['qux'])
    expect(iterator.getOpenTags()).toEqual([])

    iterator.moveToSuccessor()
    expect(iterator.getPosition()).toEqual(Point(1, 0))
    expect(iterator.getCloseTags()).toEqual([])
    expect(iterator.getOpenTags()).toEqual(['foo'])

    iterator.moveToSuccessor()
    expect(iterator.getPosition()).toEqual(Point(2, 0))
    expect(iterator.getCloseTags()).toEqual(['foo'])
    expect(iterator.getOpenTags()).toEqual([])
  })
})
