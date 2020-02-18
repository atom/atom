/*
 * Conflict parser visitor that ignores all events.
 */
export class NoopVisitor {
  visitOurSide(position, bannerRow, textRowStart, textRowEnd) { }

  visitBaseSide(position, bannerRow, textRowStart, textRowEnd) { }

  visitSeparator(sepRowStart) { }

  visitTheirSide(position, bannerRow, textRowStart, textRowEnd) { }
}
