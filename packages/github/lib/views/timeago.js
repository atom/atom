import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import cx from 'classnames';

moment.defineLocale('en-shortdiff', {
  parentLocale: 'en',
  relativeTime: {
    future: 'in %s',
    past: '%s ago',
    s: 'Now',
    ss: '<1m',
    m: '1m',
    mm: '%dm',
    h: '1h',
    hh: '%dh',
    d: '1d',
    dd: '%dd',
    M: '1M',
    MM: '%dM',
    y: '1y',
    yy: '%dy',
  },
});
moment.locale('en');

export default class Timeago extends React.Component {
  static propTypes = {
    time: PropTypes.any.isRequired,
    type: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.func,
    ]),
    displayStyle: PropTypes.oneOf(['short', 'long']),
  }

  static defaultProps = {
    type: 'span',
    displayStyle: 'long',
  }

  static getTimeDisplay(time, now, style) {
    const m = moment(time);
    if (style === 'short') {
      m.locale('en-shortdiff');
      return m.from(now, true);
    } else {
      const diff = m.diff(now, 'months', true);
      if (Math.abs(diff) <= 1) {
        m.locale('en');
        return m.from(now);
      } else {
        const format = m.format('MMM Do, YYYY');
        return `on ${format}`;
      }
    }
  }

  componentDidMount() {
    this.timer = setInterval(() => this.forceUpdate(), 60000);
  }

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  render() {
    const {type, time, displayStyle, ...others} = this.props;
    const display = Timeago.getTimeDisplay(time, moment(), displayStyle);
    const Type = type;
    const className = cx('timeago', others.className);
    return (
      <Type {...others} className={className}>{display}</Type>
    );
  }
}
