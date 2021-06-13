/* multi-line expressions */
req
  .shouldBeOne();
too.
  more.
  shouldBeOneToo;

const a =
  long_expression;

b =
  long;

b =
  3 + 5;

b =
  3
    + 5;

b =
  3
    + 5
    + 7
    + 8
      * 8
      * 9
      / 17
      * 8
      / 20
    - 34
    + 3 *
      9
    - 8;

ifthis
  && thendo()
  || otherwise
    && dothis

/**
  A comment, should be at 1
*/
