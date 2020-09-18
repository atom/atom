const {Range} = require('atom');

class LeadingContextRow {
  constructor(rowGroup, line, separator, matchLineNumber, rowOffset) {
    this.group = rowGroup
    this.rowOffset = rowOffset
    // props
    this.data = {
      separator,
      line,
      lineNumber: matchLineNumber - rowOffset,
      matchLineNumber,
    }
  }
}

class TrailingContextRow {
  constructor(rowGroup, line, separator, matchLineNumber, rowOffset) {
    this.group = rowGroup
    this.rowOffset = rowOffset
    // props
    this.data = {
      separator,
      line,
      lineNumber: matchLineNumber + rowOffset,
      matchLineNumber,
    }
  }
}

class ResultPathRow {
  constructor(rowGroup) {
    this.group = rowGroup
    // props
    this.data = {
      separator: false,
    }
  }
}

class MatchRow {
  constructor(rowGroup, separator, lineNumber, matches) {
    this.group = rowGroup
    // props
    this.data = {
      separator,
      lineNumber,
      matchLineNumber: lineNumber,
      matches,
    }
  }
}

class ResultRowGroup {
  constructor(result, findOptions) {
    this.data = { isCollapsed: false }
    this.setResult(result)

    this.rows = []
    this.collapsedRows = []
    this.generateRows(findOptions)
    this.previousRowCount = this.rows.length
  }

  setResult(result) {
    this.result = result
    this.data = {
      filePath: result.filePath,
      matchCount: result.matches.length,
      isCollapsed: this.data.isCollapsed,
    }
  }

  generateRows(findOptions) {
    const { leadingContextLineCount, trailingContextLineCount } = findOptions
    this.leadingContextLineCount = leadingContextLineCount
    this.trailingContextLineCount = trailingContextLineCount
    let rowArrays = [ [new ResultPathRow(this)] ]

    // This loop accumulates the match lines and the context lines of the
    // result; the added complexity comes from the fact that there musn't be
    // context lines between adjacent match lines
    let prevMatch = null
    let prevMatchRow = null
    let prevLineNumber
    for (const match of this.result.matches) {
      const { leadingContextLines } = match
      const lineNumber = Range.fromObject(match.range).start.row

      let leadCount
      if (prevMatch) {
        const interval = Math.max(lineNumber - prevLineNumber - 1, 0)

        const trailCount = Math.min(trailingContextLineCount, interval)
        const { trailingContextLines } = prevMatch
        rowArrays.push(
          trailingContextLines.slice(0, trailCount).map((line, i) => (
            new TrailingContextRow(this, line, false, prevLineNumber, i + 1)
          ))
        )
        leadCount = Math.min(leadingContextLineCount, interval - trailCount)
      } else {
        leadCount = Math.min(leadingContextLineCount, leadingContextLines.length)
      }

      rowArrays.push(
        leadingContextLines.slice(leadingContextLines.length - leadCount).map((line, i) => (
          new LeadingContextRow(this, line, false, lineNumber, leadCount - i)
        ))
      )

      if (prevMatchRow && lineNumber === prevLineNumber) {
        prevMatchRow.data.matches.push(match)
      } else {
        prevMatchRow = new MatchRow(this, false, lineNumber, [match])
        rowArrays.push([ prevMatchRow ])
      }

      prevMatch = match
      prevLineNumber = lineNumber
    }

    const { trailingContextLines } = prevMatch
    rowArrays.push(
      trailingContextLines.slice(0, trailingContextLineCount).map((line, i) => (
        new TrailingContextRow(this, line, false, prevLineNumber, i + 1)
      ))
    )
    this.rows = [].concat(...rowArrays)
    this.collapsedRows = [ this.rows[0] ]

    let prevRow = null
    for (const row of this.rows) {
      row.data.separator = (
        prevRow &&
        row.data.lineNumber != null && prevRow.data.lineNumber != null &&
        row.data.lineNumber > prevRow.data.lineNumber + 1
      ) ? true : false
      prevRow = row
    }
  }

  displayedRows() {
    return this.data.isCollapsed ? this.collapsedRows : this.rows
  }
}

module.exports = {
  LeadingContextRow,
  TrailingContextRow,
  ResultPathRow,
  MatchRow,
  ResultRowGroup
}
