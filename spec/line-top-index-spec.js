/** @babel */

const LineTopIndex = require('../src/linear-line-top-index')

describe("LineTopIndex", function () {
  let lineTopIndex

  beforeEach(function () {
    lineTopIndex = new LineTopIndex()
    lineTopIndex.setDefaultLineHeight(10)
    lineTopIndex.setMaxRow(12)
  })

  describe("::topPixelPositionForRow(row)", function () {
    it("performs the simple math when there are no block decorations", function () {
      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(40)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(50)
      expect(lineTopIndex.topPixelPositionForRow(12)).toBe(120)
      expect(lineTopIndex.topPixelPositionForRow(13)).toBe(120)
      expect(lineTopIndex.topPixelPositionForRow(14)).toBe(120)

      lineTopIndex.splice(0, 2, 3)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(40)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(50)
      expect(lineTopIndex.topPixelPositionForRow(12)).toBe(120)
      expect(lineTopIndex.topPixelPositionForRow(13)).toBe(130)
      expect(lineTopIndex.topPixelPositionForRow(14)).toBe(130)
    })

    it("takes into account inserted and removed blocks", function () {
      let block1 = lineTopIndex.insertBlock(0, 10)
      let block2 = lineTopIndex.insertBlock(3, 20)
      let block3 = lineTopIndex.insertBlock(5, 20)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(1)).toBe(20)
      expect(lineTopIndex.topPixelPositionForRow(2)).toBe(30)
      expect(lineTopIndex.topPixelPositionForRow(3)).toBe(40)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(70)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(80)
      expect(lineTopIndex.topPixelPositionForRow(6)).toBe(110)

      lineTopIndex.removeBlock(block1)
      lineTopIndex.removeBlock(block3)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(1)).toBe(10)
      expect(lineTopIndex.topPixelPositionForRow(2)).toBe(20)
      expect(lineTopIndex.topPixelPositionForRow(3)).toBe(30)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(60)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(70)
      expect(lineTopIndex.topPixelPositionForRow(6)).toBe(80)
    })

    it("moves blocks down/up when splicing regions", function () {
      let block1 = lineTopIndex.insertBlock(3, 20)
      let block2 = lineTopIndex.insertBlock(5, 30)

      lineTopIndex.splice(0, 0, 4)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(6)).toBe(60)
      expect(lineTopIndex.topPixelPositionForRow(7)).toBe(70)
      expect(lineTopIndex.topPixelPositionForRow(8)).toBe(100)
      expect(lineTopIndex.topPixelPositionForRow(9)).toBe(110)
      expect(lineTopIndex.topPixelPositionForRow(10)).toBe(150)
      expect(lineTopIndex.topPixelPositionForRow(11)).toBe(160)

      lineTopIndex.splice(0, 6, 2)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(3)).toBe(30)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(60)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(70)
      expect(lineTopIndex.topPixelPositionForRow(6)).toBe(110)

      lineTopIndex.splice(2, 4, 0)

      expect(lineTopIndex.topPixelPositionForRow(0)).toBe(0)
      expect(lineTopIndex.topPixelPositionForRow(1)).toBe(10)
      expect(lineTopIndex.topPixelPositionForRow(2)).toBe(20)
      expect(lineTopIndex.topPixelPositionForRow(3)).toBe(80)
      expect(lineTopIndex.topPixelPositionForRow(4)).toBe(90)
      expect(lineTopIndex.topPixelPositionForRow(5)).toBe(100)
      expect(lineTopIndex.topPixelPositionForRow(6)).toBe(110)
      expect(lineTopIndex.topPixelPositionForRow(7)).toBe(120)
      expect(lineTopIndex.topPixelPositionForRow(8)).toBe(130)
      expect(lineTopIndex.topPixelPositionForRow(9)).toBe(130)
    })
  })

  describe("::rowForTopPixelPosition(top)", function () {
    it("performs the simple math when there are no block decorations", function () {
      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(40)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(44)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(46)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(50)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(120)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(130)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(140)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(145)).toBe(12)

      lineTopIndex.splice(0, 2, 3)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(40)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(50)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(120)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(130)).toBe(13)
      expect(lineTopIndex.rowForTopPixelPosition(140)).toBe(13)
    })

    it("takes into account inserted and removed blocks", function () {
      let block1 = lineTopIndex.insertBlock(0, 10)
      let block2 = lineTopIndex.insertBlock(3, 20)
      let block3 = lineTopIndex.insertBlock(5, 20)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(6)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(10)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(12)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(17)).toBe(1)
      expect(lineTopIndex.rowForTopPixelPosition(20)).toBe(1)
      expect(lineTopIndex.rowForTopPixelPosition(30)).toBe(2)
      expect(lineTopIndex.rowForTopPixelPosition(40)).toBe(3)
      expect(lineTopIndex.rowForTopPixelPosition(70)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(80)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(90)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(95)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(105)).toBe(6)
      expect(lineTopIndex.rowForTopPixelPosition(110)).toBe(6)
      expect(lineTopIndex.rowForTopPixelPosition(160)).toBe(11)
      expect(lineTopIndex.rowForTopPixelPosition(166)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(170)).toBe(12)
      expect(lineTopIndex.rowForTopPixelPosition(240)).toBe(12)

      lineTopIndex.removeBlock(block1)
      lineTopIndex.removeBlock(block3)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(10)).toBe(1)
      expect(lineTopIndex.rowForTopPixelPosition(20)).toBe(2)
      expect(lineTopIndex.rowForTopPixelPosition(30)).toBe(3)
      expect(lineTopIndex.rowForTopPixelPosition(60)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(70)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(80)).toBe(6)
    })

    it("moves blocks down/up when splicing regions", function () {
      let block1 = lineTopIndex.insertBlock(3, 20)
      let block2 = lineTopIndex.insertBlock(5, 30)

      lineTopIndex.splice(0, 0, 4)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(60)).toBe(6)
      expect(lineTopIndex.rowForTopPixelPosition(70)).toBe(7)
      expect(lineTopIndex.rowForTopPixelPosition(100)).toBe(8)
      expect(lineTopIndex.rowForTopPixelPosition(110)).toBe(9)
      expect(lineTopIndex.rowForTopPixelPosition(150)).toBe(10)
      expect(lineTopIndex.rowForTopPixelPosition(160)).toBe(11)

      lineTopIndex.splice(0, 6, 2)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(30)).toBe(3)
      expect(lineTopIndex.rowForTopPixelPosition(60)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(70)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(110)).toBe(6)

      lineTopIndex.splice(2, 4, 0)

      expect(lineTopIndex.rowForTopPixelPosition(0)).toBe(0)
      expect(lineTopIndex.rowForTopPixelPosition(10)).toBe(1)
      expect(lineTopIndex.rowForTopPixelPosition(20)).toBe(2)
      expect(lineTopIndex.rowForTopPixelPosition(80)).toBe(3)
      expect(lineTopIndex.rowForTopPixelPosition(90)).toBe(4)
      expect(lineTopIndex.rowForTopPixelPosition(100)).toBe(5)
      expect(lineTopIndex.rowForTopPixelPosition(110)).toBe(6)
      expect(lineTopIndex.rowForTopPixelPosition(120)).toBe(7)
      expect(lineTopIndex.rowForTopPixelPosition(130)).toBe(8)
      expect(lineTopIndex.rowForTopPixelPosition(130)).toBe(8)
    })
  })
})
