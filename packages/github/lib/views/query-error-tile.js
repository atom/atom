import React from 'react';
import PropTypes from 'prop-types';

import Octicon from '../atom/octicon';

export default class QueryErrorTile extends React.Component {
  static propTypes = {
    error: PropTypes.shape({
      response: PropTypes.shape({
        status: PropTypes.number.isRequired,
      }),
      responseText: PropTypes.string,
      network: PropTypes.bool,
      errors: PropTypes.arrayOf(PropTypes.shape({
        message: PropTypes.string.isRequired,
      })),
    }).isRequired,
  }

  componentDidMount() {
    // eslint-disable-next-line no-console
    console.error('Error encountered in subquery', this.props.error);
  }

  render() {
    return (
      <div className="github-QueryErrorTile">
        <div className="github-QueryErrorTile-messages">
          {this.renderMessages()}
        </div>
      </div>
    );
  }

  renderMessages() {
    if (this.props.error.errors) {
      return this.props.error.errors.map((error, index) => {
        return this.renderMessage(error.message, index, 'alert');
      });
    }

    if (this.props.error.response) {
      return this.renderMessage(this.props.error.responseText, '0', 'alert');
    }

    if (this.props.error.network) {
      return this.renderMessage('Offline', '0', 'alignment-unalign');
    }

    return this.renderMessage(this.props.error.toString(), '0', 'alert');
  }

  renderMessage(body, key, icon) {
    return (
      <p key={key} className="github-QueryErrorTile-message">
        <Octicon icon={icon} />
        {body}
      </p>
    );
  }
}
