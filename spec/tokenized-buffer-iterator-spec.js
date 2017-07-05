/** @babel */

import TokenizedBufferIterator from '../src/tokenized-buffer-iterator'
import {Point} from 'text-buffer'

describe('TokenizedBufferIterator', () => {
  describe('seek(position)', function () {
    it('seeks to the leftmost tag boundary greater than or equal to the given position and returns the containing tags', function () {
      const tokenizedBuffer = {
        tokenizedLineForRow (row) {
          if (row === 0) {
            return {
              tags: [-1, -2, -3, -4, -5, 3, -3, -4, -6, -5, 4, -6, -3, -4],
              text: 'foo bar',
              openScopes: []
            }
          } else {
            return null
          }
        }
      }

      const iterator = new TokenizedBufferIterator(tokenizedBuffer)

      expect(iterator.seek(Point(0, 0))).toEqual([])
      expect(iterator.getPosition()).toEqual(Point(0, 0))
      expect(iterator.getCloseScopeIds()).toEqual([])
      expect(iterator.getOpenScopeIds()).toEqual([257])

      iterator.moveToSuccessor()
      expect(iterator.getCloseScopeIds()).toEqual([257])
      expect(iterator.getOpenScopeIds()).toEqual([259])

      expect(iterator.seek(Point(0, 1))).toEqual([261])
      expect(iterator.getPosition()).toEqual(Point(0, 3))
      expect(iterator.getCloseScopeIds()).toEqual([])
      expect(iterator.getOpenScopeIds()).toEqual([259])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 3))
      expect(iterator.getCloseScopeIds()).toEqual([259, 261])
      expect(iterator.getOpenScopeIds()).toEqual([261])

      expect(iterator.seek(Point(0, 3))).toEqual([261])
      expect(iterator.getPosition()).toEqual(Point(0, 3))
      expect(iterator.getCloseScopeIds()).toEqual([])
      expect(iterator.getOpenScopeIds()).toEqual([259])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 3))
      expect(iterator.getCloseScopeIds()).toEqual([259, 261])
      expect(iterator.getOpenScopeIds()).toEqual([261])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 7))
      expect(iterator.getCloseScopeIds()).toEqual([261])
      expect(iterator.getOpenScopeIds()).toEqual([259])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 7))
      expect(iterator.getCloseScopeIds()).toEqual([259])
      expect(iterator.getOpenScopeIds()).toEqual([])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(1, 0))
      expect(iterator.getCloseScopeIds()).toEqual([])
      expect(iterator.getOpenScopeIds()).toEqual([])

      expect(iterator.seek(Point(0, 5))).toEqual([261])
      expect(iterator.getPosition()).toEqual(Point(0, 7))
      expect(iterator.getCloseScopeIds()).toEqual([261])
      expect(iterator.getOpenScopeIds()).toEqual([259])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 7))
      expect(iterator.getCloseScopeIds()).toEqual([259])
      expect(iterator.getOpenScopeIds()).toEqual([])
    })
  })

  describe('moveToSuccessor()', function () {
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

      const iterator = new TokenizedBufferIterator(tokenizedBuffer)

      iterator.seek(Point(0, 0))
      expect(iterator.getPosition()).toEqual(Point(0, 0))
      expect(iterator.getCloseScopeIds()).toEqual([])
      expect(iterator.getOpenScopeIds()).toEqual([257])

      iterator.moveToSuccessor()
      expect(iterator.getPosition()).toEqual(Point(0, 0))
      expect(iterator.getCloseScopeIds()).toEqual([257])
      expect(iterator.getOpenScopeIds()).toEqual([257])

      iterator.moveToSuccessor()
      expect(iterator.getCloseScopeIds()).toEqual([257])
      expect(iterator.getOpenScopeIds()).toEqual([])
    })
  })
})
