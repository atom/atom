import moment from 'moment';

import Timeago from '../../lib/views/timeago';

function test(kindOfDisplay, style, modifier, expectation) {
  it(`displays correctly for ${kindOfDisplay}`, function() {
    const base = moment('May 6 1987', 'MMMM D YYYY');
    const m = modifier(moment(base)); // copy `base` since `modifier` mutates
    assert.equal(Timeago.getTimeDisplay(m, base, style), expectation);
  });
}

describe('Timeago component', function() {
  describe('long time display calcuation', function() {
    test('recent items', 'long', m => m, 'a few seconds ago');
    test('items within a minute', 'long', m => m.subtract(45, 'seconds'), 'a minute ago');
    test('items within two minutes', 'long', m => m.subtract(2, 'minutes'), '2 minutes ago');
    test('items within five minutes', 'long', m => m.subtract(5, 'minutes'), '5 minutes ago');
    test('items within thirty minutes', 'long', m => m.subtract(30, 'minutes'), '30 minutes ago');
    test('items within an hour', 'long', m => m.subtract(1, 'hours'), 'an hour ago');
    test('items within the same day', 'long', m => m.subtract(20, 'hours'), '20 hours ago');
    test('items within a day', 'long', m => m.subtract(1, 'day'), 'a day ago');
    test('items within the same week', 'long', m => m.subtract(4, 'days'), '4 days ago');
    test('items within the same month', 'long', m => m.subtract(20, 'days'), '20 days ago');
    test('items within a month', 'long', m => m.subtract(1, 'month'), 'a month ago');
    test('items beyond a month', 'long', m => m.subtract(31, 'days'), 'on Apr 5th, 1987');
    test('items way beyond a month', 'long', m => m.subtract(2, 'years'), 'on May 6th, 1985');
  });

  describe('short time display calcuation', function() {
    test('recent items', 'short', m => m, 'Now');
    test('items within a minute', 'short', m => m.subtract(45, 'seconds'), '1m');
    test('items within two minutes', 'short', m => m.subtract(2, 'minutes'), '2m');
    test('items within five minutes', 'short', m => m.subtract(5, 'minutes'), '5m');
    test('items within thirty minutes', 'short', m => m.subtract(30, 'minutes'), '30m');
    test('items within an hour', 'short', m => m.subtract(1, 'hours'), '1h');
    test('items within the same day', 'short', m => m.subtract(20, 'hours'), '20h');
    test('items within a day', 'short', m => m.subtract(1, 'day'), '1d');
    test('items within the same week', 'short', m => m.subtract(4, 'days'), '4d');
    test('items within the same month', 'short', m => m.subtract(20, 'days'), '20d');
    test('items within a month', 'short', m => m.subtract(1, 'month'), '1M');
    test('items beyond a month', 'short', m => m.subtract(31, 'days'), '1M');
    test('items way beyond a month', 'short', m => m.subtract(2, 'years'), '2y');
  });
});
