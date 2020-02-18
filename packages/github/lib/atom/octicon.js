import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

/* eslint-disable max-len */
const SVG = {
  unlock: {
    viewBox: '0 0 24 16',
    element: (
      <path
        fillRule="evenodd"
        d="m 13.4,13 h -1 v -1 h 1 z m 6,-7 h 1 c 0.55,0 1,0.45 1,1 v 7 c 0,0.55 -0.45,1 -1,1 h -10 c -0.55,0 -1,-0.45 -1,-1 V 7 c 0,-0.55 0.45,-1 1,-1 h 1 V 4.085901 C 11.4,2.1862908 9.8780193,2.4095693 8.904902,2.4143325 8.0404588,2.4185637 6.3689542,2.1882296 6.3689542,4.085901 V 7.4918301 L 4.2521568,7.4509801 4.2930068,4.045051 C 4.3176792,1.987953 5.080245,-0.02206145 8.792353,-0.03403364 13.536238,-0.0493335 13.21,3.1688541 13.21,4.085901 V 6 h -0.01 4.41 m 2.79,1 h -9 v 7 h 9 z m -7,1 h -1 v 1 h 1 z m 0,2 h -1 v 1 h 1 z"
      />
    ),
  },
};
/* eslint-enable max-len */

export default function Octicon({icon, ...others}) {
  const classes = cx('icon', `icon-${icon}`, others.className);

  const svgContent = SVG[icon];
  if (svgContent) {
    return (
      <svg {...others} viewBox={svgContent.viewBox} xmlns="http://www.w3.org/2000/svg" className={classes}>
        {svgContent.element}
      </svg>
    );
  }

  return <span {...others} className={classes} />;
}

Octicon.propTypes = {
  icon: PropTypes.string.isRequired,
};
