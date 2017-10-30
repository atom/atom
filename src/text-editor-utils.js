// This file is temporary. We should gradually convert methods in `text-editor.coffee`
// from CoffeeScript to JavaScript and move them here, so that we can eventually convert
// the entire class to JavaScript.

const {Point, Range} = require('text-buffer')

const NON_WHITESPACE_REGEX = /\S/

module.exports = {
  toggleLineCommentsForBufferRows (start, end) {
    let {
      commentStartString,
      commentEndString
    } = this.tokenizedBuffer.commentStringsForPosition(Point(start, 0))
    if (!commentStartString) return
    commentStartString = commentStartString.trim()

    if (commentEndString) {
      commentEndString = commentEndString.trim()
      const startDelimiterColumnRange = columnRangeForStartDelimiter(
        this.buffer.lineForRow(start),
        commentStartString
      )
      if (startDelimiterColumnRange) {
        const endDelimiterColumnRange = columnRangeForEndDelimiter(
          this.buffer.lineForRow(end),
          commentEndString
        )
        if (endDelimiterColumnRange) {
          this.buffer.transact(() => {
            this.buffer.delete([[end, endDelimiterColumnRange[0]], [end, endDelimiterColumnRange[1]]])
            this.buffer.delete([[start, startDelimiterColumnRange[0]], [start, startDelimiterColumnRange[1]]])
          })
        }
      } else {
        this.buffer.transact(() => {
          const indentLength = this.buffer.lineForRow(start).match(/^\s*/)[0].length
          this.buffer.insert([start, indentLength], commentStartString + ' ')
          this.buffer.insert([end, this.buffer.lineLengthForRow(end)], ' ' + commentEndString)
        })
      }
    } else {
      let hasCommentedLines = false
      let hasUncommentedLines = false
      for (let row = start; row <= end; row++) {
        const line = this.buffer.lineForRow(row)
        if (NON_WHITESPACE_REGEX.test(line)) {
          if (columnRangeForStartDelimiter(line, commentStartString)) {
            hasCommentedLines = true
          } else {
            hasUncommentedLines = true
          }
        }
      }

      const shouldUncomment = hasCommentedLines && !hasUncommentedLines

      if (shouldUncomment) {
        for (let row = start; row <= end; row++) {
          const columnRange = columnRangeForStartDelimiter(
            this.buffer.lineForRow(row),
            commentStartString
          )
          if (columnRange) this.buffer.delete([[row, columnRange[0]], [row, columnRange[1]]])
        }
      } else {
        let minIndentLevel = Infinity
        let minBlankIndentLevel = Infinity
        for (let row = start; row <= end; row++) {
          const line = this.buffer.lineForRow(row)
          const indentLevel = this.indentLevelForLine(line)
          if (NON_WHITESPACE_REGEX.test(line)) {
            if (indentLevel < minIndentLevel) minIndentLevel = indentLevel
          } else {
            if (indentLevel < minBlankIndentLevel) minBlankIndentLevel = indentLevel
          }
        }
        minIndentLevel = Number.isFinite(minIndentLevel)
          ? minIndentLevel
          : Number.isFinite(minBlankIndentLevel)
              ? minBlankIndentLevel
              : 0

        const tabLength = this.getTabLength()
        const indentString = ' '.repeat(tabLength * minIndentLevel)
        for (let row = start; row <= end; row++) {
          const line = this.buffer.lineForRow(row)
          if (NON_WHITESPACE_REGEX.test(line)) {
            const indentColumn = columnForIndentLevel(line, minIndentLevel, this.getTabLength())
            this.buffer.insert(Point(row, indentColumn), commentStartString + ' ')
          } else {
            this.buffer.setTextInRange(
              new Range(new Point(row, 0), new Point(row, Infinity)),
              indentString + commentStartString + ' '
            )
          }
        }
      }
    }
  }
}

function columnForIndentLevel (line, indentLevel, tabLength) {
  let column = 0
  let indentLength = 0
  const goalIndentLength = indentLevel * tabLength
  while (indentLength < goalIndentLength) {
    const char = line[column]
    if (char === '\t') {
      indentLength += tabLength - (indentLength % tabLength)
    } else if (char === ' ') {
      indentLength++
    } else {
      break
    }
    column++
  }
  return column
}

function columnRangeForStartDelimiter (line, delimiter) {
  const startColumn = line.search(NON_WHITESPACE_REGEX)
  if (startColumn === -1) return null
  if (!line.startsWith(delimiter, startColumn)) return null

  let endColumn = startColumn + delimiter.length
  if (line[endColumn] === ' ') endColumn++
  return [startColumn, endColumn]
}

function columnRangeForEndDelimiter (line, delimiter) {
  let startColumn = line.lastIndexOf(delimiter)
  if (startColumn === -1) return null

  const endColumn = startColumn + delimiter.length
  if (NON_WHITESPACE_REGEX.test(line.slice(endColumn))) return null
  if (line[startColumn - 1] === ' ') startColumn--
  return [startColumn, endColumn]
}
