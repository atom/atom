import {NoopVisitor} from './noop-visitor';
import {TOP, BOTTOM} from '../position';

class Result {
  constructor(remainingSteps) {
    this.steps = remainingSteps;
  }

  wasSuccessful() {
    return this.steps.length === 0;
  }
}

export class ConflictParser {
  constructor(adapter, visitor, isRebase) {
    this.adapter = adapter;
    this.visitor = visitor;
    this.isRebase = isRebase;

    this.lastBoundary = null;
    this.steps = [];

    if (this.isRebase) {
      this.steps.push(parser => parser.visitHeaderSide(TOP, 'visitTheirSide'));
      this.steps.push(parser => parser.visitBaseAndSeparator());
      this.steps.push(parser => parser.visitFooterSide(BOTTOM, 'visitOurSide'));
    } else {
      this.steps.push(parser => parser.visitHeaderSide(TOP, 'visitOurSide'));
      this.steps.push(parser => parser.visitBaseAndSeparator());
      this.steps.push(parser => parser.visitFooterSide(BOTTOM, 'visitTheirSide'));
    }
  }

  continueFrom(result) {
    this.steps = result.steps;
    return this.parse();
  }

  parse() {
    for (let i = 0; i < this.steps.length; i++) {
      if (!this.steps[i](this)) {
        return new Result(this.steps.slice(i));
      }
    }
    return new Result([]);
  }

  // Visit a side that begins with a banner and description as its first line.
  visitHeaderSide(position, visitMethod) {
    const sideRowStart = this.adapter.getCurrentRow();
    this.adapter.advanceRow();

    if (this.advanceToBoundary('|=') === null) {
      return false;
    }

    const sideRowEnd = this.adapter.getCurrentRow();

    this.visitor[visitMethod](position, sideRowStart, sideRowStart + 1, sideRowEnd);
    return true;
  }

  // Visit the base side from diff3 output, if one is present, then visit the separator.
  visitBaseAndSeparator() {
    if (this.lastBoundary === '|') {
      if (!this.visitBaseSide()) {
        return false;
      }
    }

    return this.visitSeparator();
  }

  // Visit a base side from diff3 output.
  visitBaseSide() {
    const sideRowStart = this.adapter.getCurrentRow();
    this.adapter.advanceRow();

    let b = this.advanceToBoundary('<=');
    if (b === null) {
      return false;
    }

    while (b === '<') {
      // Embedded recursive conflict within a base side, caused by a criss-cross merge.
      // Advance the input adapter beyond it without marking anything.
      const subParser = new ConflictParser(this.adapter, new NoopVisitor(), this.isRebase);
      if (!subParser.parse().wasSuccessful()) {
        return false;
      }

      b = this.advanceToBoundary('<=');
      if (b === null) {
        return false;
      }
    }

    const sideRowEnd = this.adapter.getCurrentRow();
    this.visitor.visitBaseSide(sideRowStart, sideRowStart + 1, sideRowEnd);
    return true;
  }

  // Visit a "========" separator.
  visitSeparator() {
    const sepRowStart = this.adapter.getCurrentRow();
    this.adapter.advanceRow();
    const sepRowEnd = this.adapter.getCurrentRow();

    this.visitor.visitSeparator(sepRowStart, sepRowEnd);
    return true;
  }

  // Visit a side with a banner and description as its last line.
  visitFooterSide(position, visitMethod) {
    const sideRowStart = this.adapter.getCurrentRow();
    if (this.advanceToBoundary('>') === null) {
      return false;
    }

    this.adapter.advanceRow();
    const sideRowEnd = this.adapter.getCurrentRow();

    this.visitor[visitMethod](position, sideRowEnd - 1, sideRowStart, sideRowEnd - 1);
    return true;
  }

  // Determine if the current row is a side boundary.
  //
  // boundaryKinds - [String] any combination of <, |, =, or > to limit the kinds of boundary detected.
  //
  // Returns the matching boundaryKinds character, or `null` if none match.
  isAtBoundary(boundaryKinds = '<|=>') {
    const line = this.adapter.getCurrentLine();
    for (let i = 0; i < boundaryKinds.length; i++) {
      const b = boundaryKinds[i];
      if (line.startsWith(b.repeat(7))) {
        return b;
      }
    }
    return null;
  }

  // Increment the current row until the current line matches one of the provided boundary kinds, or until there are no
  // more lines in the editor.
  //
  // boundaryKinds - [String] any combination of <, |, =, or > to limit the kinds of boundaries that halt the
  //   progression.
  //
  // Returns the matching boundaryKinds character, or 'null' if there are no matches to the end of the editor.
  advanceToBoundary(boundaryKinds = '<|=>') {
    let b = this.isAtBoundary(boundaryKinds);
    while (b === null) {
      this.adapter.advanceRow();
      if (this.adapter.isAtEnd()) {
        return null;
      }
      b = this.isAtBoundary(boundaryKinds);
    }

    this.lastBoundary = b;
    return b;
  }
}
