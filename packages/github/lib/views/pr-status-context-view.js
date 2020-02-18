import React from 'react';
import {createFragmentContainer, graphql} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../atom/octicon';
import {buildStatusFromStatusContext} from '../models/build-status';

export class BarePrStatusContextView extends React.Component {
  static propTypes = {
    context: PropTypes.shape({
      context: PropTypes.string.isRequired,
      description: PropTypes.string,
      state: PropTypes.string.isRequired,
      targetUrl: PropTypes.string,
    }).isRequired,
  }

  render() {
    const {context, description, state, targetUrl} = this.props.context;
    const {icon, classSuffix} = buildStatusFromStatusContext({state});
    return (
      <li className="github-PrStatuses-list-item">
        <span className="github-PrStatuses-list-item-icon">
          <Octicon icon={icon} className={`github-PrStatuses--${classSuffix}`} />
        </span>
        <span className="github-PrStatuses-list-item-context">
          <strong>{context}</strong> {description}
        </span>
        <span className="github-PrStatuses-list-item-details-link">
          <a href={targetUrl}>Details</a>
        </span>
      </li>
    );
  }
}

export default createFragmentContainer(BarePrStatusContextView, {
  context: graphql`
    fragment prStatusContextView_context on StatusContext {
      context
      description
      state
      targetUrl
    }
  `,
});
