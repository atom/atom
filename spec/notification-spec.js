const Notification = require('../src/notification');

describe('Notification', () => {
  it('throws an error when created with a non-string message', () => {
    expect(() => new Notification('error', null)).toThrow();
    expect(() => new Notification('error', 3)).toThrow();
    expect(() => new Notification('error', {})).toThrow();
    expect(() => new Notification('error', false)).toThrow();
    expect(() => new Notification('error', [])).toThrow();
  });

  it('throws an error when created with non-object options', () => {
    expect(() => new Notification('error', 'message', 'foo')).toThrow();
    expect(() => new Notification('error', 'message', 3)).toThrow();
    expect(() => new Notification('error', 'message', false)).toThrow();
    expect(() => new Notification('error', 'message', [])).toThrow();
  });

  describe('::getTimestamp()', () =>
    it('returns a Date object', () => {
      const notification = new Notification('error', 'message!');
      expect(notification.getTimestamp() instanceof Date).toBe(true);
    }));

  describe('::getIcon()', () => {
    it('returns a default when no icon specified', () => {
      const notification = new Notification('error', 'message!');
      expect(notification.getIcon()).toBe('flame');
    });

    it('returns the icon specified', () => {
      const notification = new Notification('error', 'message!', {
        icon: 'my-icon'
      });
      expect(notification.getIcon()).toBe('my-icon');
    });
  });

  describe('dismissing notifications', () => {
    describe('when the notfication is dismissable', () =>
      it('calls a callback when the notification is dismissed', () => {
        const dismissedSpy = jasmine.createSpy();
        const notification = new Notification('error', 'message', {
          dismissable: true
        });
        notification.onDidDismiss(dismissedSpy);

        expect(notification.isDismissable()).toBe(true);
        expect(notification.isDismissed()).toBe(false);

        notification.dismiss();

        expect(dismissedSpy).toHaveBeenCalled();
        expect(notification.isDismissed()).toBe(true);
      }));

    describe('when the notfication is not dismissable', () =>
      it('does nothing when ::dismiss() is called', () => {
        const dismissedSpy = jasmine.createSpy();
        const notification = new Notification('error', 'message');
        notification.onDidDismiss(dismissedSpy);

        expect(notification.isDismissable()).toBe(false);
        expect(notification.isDismissed()).toBe(true);

        notification.dismiss();

        expect(dismissedSpy).not.toHaveBeenCalled();
        expect(notification.isDismissed()).toBe(true);
      }));
  });
});
