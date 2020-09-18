/** @babel */

const {
  LeadingContextRow,
  TrailingContextRow,
  ResultPathRow,
  MatchRow,
  ResultRowGroup
} = require("../lib/project/result-row");

describe("ResultRowGroup", () => {
  const lines = (new Array(18)).fill().map((x, i) => `line-${i}`)
  const rg = (i) => [[i, 0], [i, lines[i].length]]
  const testedRowIndices = [0, 7, 13, 16, 17]

  const result = {
    filePath: 'fake-file-path',
    matches: testedRowIndices.map(lineNb => ({
      range: rg(lineNb),
      leadingContextLines: lines.slice(Math.max(lineNb - 3, 0), lineNb),
      trailingContextLines: lines.slice(lineNb + 1, lineNb + 4),
      lineTextOffset: 0,
      lineText: lines[lineNb],
      matchText: 'fake-match-text'
    }))
  }

  describe("generateRows", () => {
    it("generates a path row and several match rows", () => {
      const rowGroup = new ResultRowGroup(
        result,
        { leadingContextLineCount: 0, trailingContextLineCount: 0 }
      )

      const expectedRows = [
        new ResultPathRow(rowGroup),
        new MatchRow(rowGroup, false, 0, [ result.matches[0] ]),
        new MatchRow(rowGroup, true, 7, [ result.matches[1] ]),
        new MatchRow(rowGroup, true, 13, [ result.matches[2] ]),
        new MatchRow(rowGroup, true, 16, [ result.matches[3] ]),
        new MatchRow(rowGroup, false, 17, [ result.matches[4] ])
      ]

      for (let i = 0; i < rowGroup.rows.length; ++i) {
        expect(rowGroup.rows[i].data).toEqual(expectedRows[i].data)
      }
    })

    it("generates context rows between matches", () => {
      const rowGroup = new ResultRowGroup(
        result,
        { leadingContextLineCount: 3, trailingContextLineCount: 2 }
      )

      const expectedRows = [
        new ResultPathRow(rowGroup),

        new MatchRow(rowGroup, false, 0, [ result.matches[0] ]),
        new TrailingContextRow(rowGroup, lines[1], false, 0, 1),
        new TrailingContextRow(rowGroup, lines[2], false, 0, 2),

        new LeadingContextRow(rowGroup, lines[4], true, 7, 3),
        new LeadingContextRow(rowGroup, lines[5], false, 7, 2),
        new LeadingContextRow(rowGroup, lines[6], false, 7, 1),
        new MatchRow(rowGroup, false, 7, [ result.matches[1] ]),
        new TrailingContextRow(rowGroup, lines[8], false, 7, 1),
        new TrailingContextRow(rowGroup, lines[9], false, 7, 2),

        new LeadingContextRow(rowGroup, lines[10], false, 13, 3),
        new LeadingContextRow(rowGroup, lines[11], false, 13, 2),
        new LeadingContextRow(rowGroup, lines[12], false, 13, 1),
        new MatchRow(rowGroup, false, 13, [ result.matches[2] ]),
        new TrailingContextRow(rowGroup, lines[14], false, 13, 1),
        new TrailingContextRow(rowGroup, lines[15], false, 13, 2),

        new MatchRow(rowGroup, false, 16, [ result.matches[3] ]),
        new MatchRow(rowGroup, false, 17, [ result.matches[4] ])
      ]

      for (let i = 0; i < rowGroup.rows.length; ++i) {
        expect(rowGroup.rows[i].data).toEqual(expectedRows[i].data)
      }
    })
  })

  describe("getLineNumber", () => {
    it("generates correct line numbers", () => {
      const rowGroup = new ResultRowGroup(
        result,
        { leadingContextLineCount: 1, trailingContextLineCount: 1 }
      )

      expect(rowGroup.rows.slice(1).map(row => row.data.lineNumber)).toEqual(
        [0, 1, 6, 7, 8, 12, 13, 14, 15, 16, 17]
      )
    })
  })
})
