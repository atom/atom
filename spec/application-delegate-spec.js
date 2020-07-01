/** @babel */

<<<<<<< HEAD
import ApplicationDelegate from '../src/application-delegate';

describe('ApplicationDelegate', function() {
  describe('set/getTemporaryWindowState', function() {
    it('can serialize object trees containing redundant child object references', async function() {
      const applicationDelegate = new ApplicationDelegate();
      const childObject = { c: 1 };
      const sentObject = { a: childObject, b: childObject };

      await applicationDelegate.setTemporaryWindowState(sentObject);
      const receivedObject = await applicationDelegate.getTemporaryWindowState();

      expect(receivedObject).toEqual(sentObject);
    });
  });
});
=======
import {it, fit, ffit, fffit, beforeEach, afterEach} from './async-spec-helpers'
import ApplicationDelegate from '../src/application-delegate'

describe('ApplicationDelegate', function () {
  describe('set/getTemporaryWindowState', function () {
    it('can serialize object trees containing redundant child object references', async function () {
      const applicationDelegate = new ApplicationDelegate()
      const childObject = {c: 1}
      const sentObject = {a: childObject, b: childObject}

      await applicationDelegate.setTemporaryWindowState(sentObject)
      const receivedObject = await applicationDelegate.getTemporaryWindowState()

      expect(receivedObject).toEqual(sentObject)
    })
  })
})
>>>>>>> origin/1.10-releases-archived
