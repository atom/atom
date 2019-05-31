const WORDS = require('./words');
const { Point, Range } = require('text-buffer');

exports.getRandomBufferRange = function getRandomBufferRange(random, buffer) {
  const endRow = random(buffer.getLineCount());
  const startRow = random.intBetween(0, endRow);
  const startColumn = random(buffer.lineForRow(startRow).length + 1);
  const endColumn = random(buffer.lineForRow(endRow).length + 1);
  return Range(Point(startRow, startColumn), Point(endRow, endColumn));
};

exports.buildRandomLines = function buildRandomLines(random, maxLines) {
  const lines = [];

  for (let i = 0; i < random(maxLines); i++) {
    lines.push(buildRandomLine(random));
  }

  return lines.join('\n');
};

function buildRandomLine(random) {
  const line = [];

  for (let i = 0; i < random(5); i++) {
    const n = random(10);

    if (n < 2) {
      line.push('\t');
    } else if (n < 4) {
      line.push(' ');
    } else {
      if (line.length > 0 && !/\s/.test(line[line.length - 1])) {
        line.push(' ');
      }

      line.push(WORDS[random(WORDS.length)]);
    }
  }

  return line.join('');
}
