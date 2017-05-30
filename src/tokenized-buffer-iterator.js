const {Point} = require('text-buffer')
const {fromFirstMateScopeId} = require('./first-mate-helpers')

module.exports = class TokenizedBufferIterator {
  constructor (tokenizedBuffer) {
    this.tokenizedBuffer = tokenizedBuffer
    this.openScopeIds = null
    this.closeScopeIds = null
  }

  seek (position) {
    this.openScopeIds = []
    this.closeScopeIds = []
    this.tagIndex = null

    const currentLine = this.tokenizedBuffer.tokenizedLineForRow(position.row)
    this.currentLineTags = currentLine.tags
    this.currentLineLength = currentLine.text.length
    const containingScopeIds = currentLine.openScopes.map((id) => fromFirstMateScopeId(id))

    let currentColumn = 0
    for (let index = 0; index < this.currentLineTags.length; index++) {
      const tag = this.currentLineTags[index]
      if (tag >= 0) {
        if (currentColumn >= position.column) {
          this.tagIndex = index
          break
        } else {
          currentColumn += tag
          while (this.closeScopeIds.length > 0) {
            this.closeScopeIds.shift()
            containingScopeIds.pop()
          }
          while (this.openScopeIds.length > 0) {
            const openTag = this.openScopeIds.shift()
            containingScopeIds.push(openTag)
          }
        }
      } else {
        const scopeId = fromFirstMateScopeId(tag)
        if ((tag & 1) === 0) {
          if (this.openScopeIds.length > 0) {
            if (currentColumn >= position.column) {
              this.tagIndex = index
              break
            } else {
              while (this.closeScopeIds.length > 0) {
                this.closeScopeIds.shift()
                containingScopeIds.pop()
              }
              while (this.openScopeIds.length > 0) {
                const openTag = this.openScopeIds.shift()
                containingScopeIds.push(openTag)
              }
            }
          }
          this.closeScopeIds.push(scopeId)
        } else {
          this.openScopeIds.push(scopeId)
        }
      }
    }

    if (this.tagIndex == null) {
      this.tagIndex = this.currentLineTags.length
    }
    this.position = Point(position.row, Math.min(this.currentLineLength, currentColumn))
    return containingScopeIds
  }

  moveToSuccessor () {
    this.openScopeIds = []
    this.closeScopeIds = []
    while (true) {
      if (this.tagIndex === this.currentLineTags.length) {
        if (this.isAtTagBoundary()) {
          break
        } else if (!this.moveToNextLine()) {
          return false
        }
      } else {
        const tag = this.currentLineTags[this.tagIndex]
        if (tag >= 0) {
          if (this.isAtTagBoundary()) {
            break
          } else {
            this.position = Point(this.position.row, Math.min(
              this.currentLineLength,
              this.position.column + this.currentLineTags[this.tagIndex]
            ))
          }
        } else {
          const scopeId = fromFirstMateScopeId(tag)
          if ((tag & 1) === 0) {
            if (this.openScopeIds.length > 0) {
              break
            } else {
              this.closeScopeIds.push(scopeId)
            }
          } else {
            this.openScopeIds.push(scopeId)
          }
        }
        this.tagIndex++
      }
    }
    return true
  }

  getPosition () {
    return this.position
  }

  getCloseScopeIds () {
    return this.closeScopeIds.slice()
  }

  getOpenScopeIds () {
    return this.openScopeIds.slice()
  }

  moveToNextLine () {
    this.position = Point(this.position.row + 1, 0)
    const tokenizedLine = this.tokenizedBuffer.tokenizedLineForRow(this.position.row)
    if (tokenizedLine == null) {
      return false
    } else {
      this.currentLineTags = tokenizedLine.tags
      this.currentLineLength = tokenizedLine.text.length
      this.tagIndex = 0
      return true
    }
  }

  isAtTagBoundary () {
    return this.closeScopeIds.length > 0 || this.openScopeIds.length > 0
  }
}
