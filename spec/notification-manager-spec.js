const NotificationManager = require('../src/notification-manager');

describe('NotificationManager', () => {
  let manager;

  beforeEach(() => {
    manager = new NotificationManager();
  });

  describe('the atom global', () =>
    it('has a notifications instance', () => {
      expect(atom.notifications instanceof NotificationManager).toBe(true);
    }));

  describe('adding events', () => {
    let addSpy;

    beforeEach(() => {
      addSpy = jasmine.createSpy();
      manager.onDidAddNotification(addSpy);
    });

    it('emits an event when a notification has been added', () => {
      manager.add('error', 'Some error!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();

      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('error');
      expect(notification.getMessage()).toBe('Some error!');
      expect(notification.getIcon()).toBe('someIcon');
    });

    it('emits a fatal error when ::addFatalError has been called', () => {
      manager.addFatalError('Some error!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();
      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('fatal');
    });

    it('emits an error when ::addError has been called', () => {
      manager.addError('Some error!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();
      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('error');
    });

    it('emits a warning notification when ::addWarning has been called', () => {
      manager.addWarning('Something!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();
      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('warning');
    });

    it('emits an info notification when ::addInfo has been called', () => {
      manager.addInfo('Something!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();
      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('info');
    });

    it('emits a success notification when ::addSuccess has been called', () => {
      manager.addSuccess('Something!', { icon: 'someIcon' });
      expect(addSpy).toHaveBeenCalled();
      const notification = addSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('success');
    });
  });

  describe('clearing notifications', () => {
    it('clears the notifications when ::clear has been called', () => {
      manager.addSuccess('success');
      expect(manager.getNotifications().length).toBe(1);
      manager.clear();
      expect(manager.getNotifications().length).toBe(0);
    });

    describe('adding events', () => {
      let clearSpy;

      beforeEach(() => {
        clearSpy = jasmine.createSpy();
        manager.onDidClearNotifications(clearSpy);
      });

      it('emits an event when the notifications have been cleared', () => {
        manager.clear();
        expect(clearSpy).toHaveBeenCalled();
      });
    });
  });
});
