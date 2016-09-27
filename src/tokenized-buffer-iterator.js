const {Point} = require('text-buffer')

module.exports = class TokenizedBufferIterator {
  constructor(tokenizedBuffer) {
    this.tokenizedBuffer = tokenizedBuffer
    this.openTags = null
    this.closeTags = null
    this.containingTags = null
  }

  seek(position) {
    this.openTags = []
    this.closeTags = []
    this.tagIndex = null

    const currentLine = this.tokenizedBuffer.tokenizedLineForRow(position.row)
    this.currentTags = currentLine.tags
    this.currentLineOpenTags = currentLine.openScopes
    this.currentLineLength = currentLine.text.length
    this.containingTags = this.currentLineOpenTags.map(id => this.tokenizedBuffer.grammar.scopeForId(id))

    let currentColumn = 0
    for (let [index, tag] of this.currentTags.entries()) {
      if (tag >= 0) {
        if (currentColumn >= position.column) {
          this.tagIndex = index
          break
        } else {
          currentColumn += tag
          while (this.closeTags.length > 0) {
            this.closeTags.shift()
            this.containingTags.pop()
          }
          while (this.openTags.length > 0) {
            const openTag = this.openTags.shift()
            this.containingTags.push(openTag)
          }
        }
      } else {
        const scopeName = this.tokenizedBuffer.grammar.scopeForId(tag)
        if (tag % 2 === 0) {
          if (this.openTags.length > 0) {
            if (currentColumn >= position.column) {
              this.tagIndex = index
              break
            } else {
              while (this.closeTags.length > 0) {
                this.closeTags.shift()
                this.containingTags.pop()
              }
              while (this.openTags.length > 0) {
                const openTag = this.openTags.shift()
                this.containingTags.push(openTag)
              }
            }
          }
          this.closeTags.push(scopeName)
        } else {
          this.openTags.push(scopeName)
        }
      }
    }

    if (this.tagIndex == null) {
      this.tagIndex = this.currentTags.length
    }
    this.position = Point(position.row, Math.min(this.currentLineLength, currentColumn))
    return this.containingTags.slice()
  }

  moveToSuccessor() {
    for (let tag of this.closeTags) {
      this.containingTags.pop()
    }
    for (let tag of this.openTags) {
      this.containingTags.push(tag)
    }
    this.openTags = []
    this.closeTags = []
    while (true) {
      if (this.tagIndex === this.currentTags.length) {
        if (this.isAtTagBoundary()) {
          break
        } else if (this.shouldMoveToNextLine) {
          this.moveToNextLine()
          this.openTags = this.currentLineOpenTags.map(id => this.tokenizedBuffer.grammar.scopeForId(id))
          this.shouldMoveToNextLine = false
        } else if (this.nextLineHasMismatchedContainingTags()) {
          this.closeTags = this.containingTags.slice().reverse()
          this.containingTags = []
          this.shouldMoveToNextLine = true
        } else if (!this.moveToNextLine()) {
          return false
        }
      } else {
        const tag = this.currentTags[this.tagIndex]
        if (tag >= 0) {
          if (this.isAtTagBoundary()) {
            break
          } else {
            this.position = Point(this.position.row, Math.min(
              this.currentLineLength,
              this.position.column + this.currentTags[this.tagIndex]
            ))
          }
        } else {
          const scopeName = this.tokenizedBuffer.grammar.scopeForId(tag)
          if (tag % 2 === 0) {
            if (this.openTags.length > 0) {
              break
            } else {
              this.closeTags.push(scopeName)
            }
          } else {
            this.openTags.push(scopeName)
          }
        }
        this.tagIndex++
      }
    }
    return true
  }

  getPosition() {
    return this.position
  }

  getCloseTags() {
    return this.closeTags.slice()
  }

  getOpenTags() {
    return this.openTags.slice()
  }

  nextLineHasMismatchedContainingTags() {
    const line = this.tokenizedBuffer.tokenizedLineForRow(this.position.row + 1)
    if (line == null) {
      return false
    } else {
      return (
        this.containingTags.length !== line.openScopes.length ||
        this.containingTags.some((tag, i) => tag !== this.tokenizedBuffer.grammar.scopeForId(line.openScopes[i]))
      )
    }
  }

  moveToNextLine() {
    this.position = Point(this.position.row + 1, 0)
    const tokenizedLine = this.tokenizedBuffer.tokenizedLineForRow(this.position.row)
    if (tokenizedLine == null) {
      return false
    } else {
      this.currentTags = tokenizedLine.tags
      this.currentLineLength = tokenizedLine.text.length
      this.currentLineOpenTags = tokenizedLine.openScopes
      this.tagIndex = 0
      return true
    }
  }

  isAtTagBoundary() {
    return this.closeTags.length > 0 || this.openTags.length > 0
  }
}
