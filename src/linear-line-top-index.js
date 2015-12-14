"use babel"

export default class LineTopIndex {
  constructor (params = {}) {
    this.blocks = []
    this.maxRow = params.maxRow || 0
    this.setDefaultLineHeight(params.defaultLineHeight || 0)
  }

  setDefaultLineHeight (lineHeight) {
    this.defaultLineHeight = lineHeight
  }

  getMaxRow () {
    return this.maxRow
  }

  insertBlock (id, row, height) {
    this.blocks.push({id, row, height})
    this.blocks.sort((a, b) => a.row - b.row)
  }

  resizeBlock (id, height) {
    let block = this.blocks.find((block) => block.id === id)
    if (block) {
      block.height = height
    }
  }

  moveBlock (id, newRow) {
    let block = this.blocks.find((block) => block.id === id)
    if (block) {
      block.row = newRow
      this.blocks.sort((a, b) => a.row - b.row)
    }
  }

  removeBlock (id) {
    let index = this.blocks.findIndex((block) => block.id === id)
    if (index !== -1) {
      this.blocks.splice(index, 1)
    }
  }

  allBlocks () {
    return this.blocks
  }

  blocksHeightForRow (row) {
    let blocksForRow = this.blocks.filter((block) => block.row === row)
    return blocksForRow.reduce((a, b) => a + b.height, 0)
  }

  splice (startRow, oldExtent, newExtent) {
    this.blocks.forEach(function (block) {
      if (block.row >= startRow) {
        if (block.row >= startRow + oldExtent) {
          block.row += newExtent - oldExtent
        } else {
          block.row = startRow + newExtent
        }
      }
    })

    this.maxRow = this.maxRow + newExtent - oldExtent
  }

  pixelPositionForRow (row) {
    row = Math.min(row, this.maxRow)
    let linesHeight = row * this.defaultLineHeight
    let blocksHeight = this.blocks.filter((block) => block.row <= row).reduce((a, b) => a + b.height, 0)
    return linesHeight + blocksHeight
  }

  rowForPixelPosition (top, strategy) {
    const roundingStrategy = strategy || 'floor'
    let blocksHeight = 0
    let lastRow = 0
    let lastTop = 0
    for (let block of this.blocks) {
      let nextBlocksHeight = blocksHeight + block.height
      let linesHeight = block.row * this.defaultLineHeight
      if (nextBlocksHeight + linesHeight > top) {
        while (lastRow < block.row && lastTop + this.defaultLineHeight <= top) {
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
    let remainingRows = Math.min(this.maxRow, lastRow + remainingHeight / this.defaultLineHeight)
    switch (roundingStrategy) {
      case 'floor':
        return Math.floor(remainingRows)
      case 'ceil':
        return Math.ceil(remainingRows)
      default:
        throw new Error(`Cannot use '${roundingStrategy}' as a rounding strategy!`)
    }
  }
}
