import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';
import {EnableableOperationPropType} from '../prop-types';
import {checkoutStates} from '../controllers/pr-checkout-controller';

export default class CheckoutButton extends React.Component {
  static propTypes = {
    checkoutOp: EnableableOperationPropType.isRequired,
    classNamePrefix: PropTypes.string.isRequired,
    classNames: PropTypes.array,
  }

  render() {
    const {checkoutOp} = this.props;
    const extraClasses = this.props.classNames || [];
    let buttonText = 'Checkout';
    let buttonTitle = null;

    if (!checkoutOp.isEnabled()) {
      buttonTitle = checkoutOp.getMessage();
      const reason = checkoutOp.why();
      if (reason === checkoutStates.HIDDEN) {
        return null;
      }

      buttonText = reason.when({
        current: 'Checked out',
        default: 'Checkout',
      });

      extraClasses.push(this.props.classNamePrefix + reason.when({
        disabled: 'disabled',
        busy: 'busy',
        current: 'current',
      }));
    }

    const classNames = cx('btn', 'btn-primary', 'checkoutButton', ...extraClasses);
    return (
      <button
        className={classNames}
        disabled={!checkoutOp.isEnabled()}
        title={buttonTitle}
        onClick={() => checkoutOp.run()}>
        {buttonText}
      </button>
    );
  }

}
