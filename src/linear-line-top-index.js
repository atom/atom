/** @babel */

module.exports =
class LineTopIndex {
  constructor () {
    this.idCounter = 0
    this.blocks = []
    this.maxRow = 0
    this.defaultLineHeight = 0
  }

  setDefaultLineHeight (lineHeight) {
    this.defaultLineHeight = lineHeight
  }

  setMaxRow (maxRow) {
    this.maxRow = maxRow
  }

  insertBlock (row, height) {
    let id = this.idCounter++
    this.blocks.push({id, row, height})
    this.blocks.sort((a, b) => a.row - b.row)
    return id
  }

  changeBlockHeight (id, height) {
    let block = this.blocks.find((block) => block.id == id)
    if (block) {
      block.height = height
    }
  }

  removeBlock (id) {
    let index = this.blocks.findIndex((block) => block.id == id)
    if (index != -1) {
      this.blocks.splice(index, 1)
    }
  }

  splice (startRow, oldExtent, newExtent) {
    this.blocks.forEach(function (block) {
      if (block.row >= startRow) {
        if (block.row >= startRow + oldExtent) {
          block.row += newExtent - oldExtent
        } else {
          block.row = startRow + newExtent
          // invalidate marker?
        }
      }
    })

    this.setMaxRow(this.maxRow + newExtent - oldExtent)
  }

  topPixelPositionForRow (row) {
    row = Math.min(row, this.maxRow)
    let linesHeight = row * this.defaultLineHeight
    let blocksHeight = this.blocks.filter((block) => block.row < row).reduce((a, b) => a + b.height, 0)
    return linesHeight + blocksHeight
  }

  bottomPixelPositionForRow (row) {
    return this.topPixelPositionForRow(row + 1) - this.defaultLineHeight
  }

  rowForTopPixelPosition (top) {
    let blocksHeight = 0
    let lastRow = 0
    let lastTop = 0
    for (let block of this.blocks) {
      let nextBlocksHeight = blocksHeight + block.height
      let linesHeight = block.row * this.defaultLineHeight
      if (nextBlocksHeight + linesHeight > top) {
        while (lastRow < block.row && lastTop + this.defaultLineHeight / 2 < top) {
          lastTop += this.defaultLineHeight
          lastRow++
        }
        return lastRow
      } else {
        blocksHeight = nextBlocksHeight
        lastRow = block.row
        lastTop = blocksHeight + linesHeight
      }
    }

    let remainingHeight = Math.max(0, top - lastTop)
    let remainingRows = Math.round(remainingHeight / this.defaultLineHeight)
    return Math.min(this.maxRow, lastRow + remainingRows)
  }
}
