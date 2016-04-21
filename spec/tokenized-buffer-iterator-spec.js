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
})
