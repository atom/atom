// tests for Query Selector related
import { expect } from 'chai';
import $ from 'jquery';

describe('query selector', () => {
  describe('basic', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <ul id='query-selector-test1' class='list'>
          <li data-role='red' class='item-i red item'>I</li>
          <li data-role='blue' class='item-ii blue item'>II</li>
          <li>III</li>
          <li>
            <ul id='nested-ul'>
              <li data-role='red' class='item-i-i red item'>III.I</li>
              <li data-role='blue' class='item-i-ii blue item'>III.II</li>
            </ul>
          </li>
        </ul>
      `;
    });

    afterEach(() => {
      const el = document.querySelector('#query-selector-test1');
      el.parentNode.removeChild(el);
    });

    it('1.0 Query by selector', () => {
      const $els = $('li.item[data-role="red"]');
      const els = document.querySelectorAll('li.item[data-role="red"]');

      expect($els.length).to.equal(2);
      [].forEach.call($els, function($el, i) {
        expect($el).to.equal(els[i]);
      });
    });

    it('1.1 Query by class', () => {
      const $els = $('.item');
      const els = document.getElementsByClassName('item');

      [].forEach.call($els, function($el, i) {
        expect($el).to.equal(els[i]);
      });
    });

    it('1.2 Query by id', () => {
      expect($('#nested-ul')[0]).to.equal(document.getElementById('nested-ul'));
    });

    it('1.3 Query by attribute', () => {
      const $els = $('[data-role="blue"]');
      const els = document.querySelectorAll('[data-role="blue"]');

      expect($els.length).to.equal(2);
      [].forEach.call($els, function($el, i) {
        expect($el).to.equal(els[i]);
      });
    });

    it('1.4 Query in descendents', () => {
      const $els = $('#query-selector-test1').find('.item');
      const els = document.getElementById('query-selector-test1').querySelectorAll('.item');

      expect($els.length).to.equal(4);
      [].forEach.call($els, function($el, i) {
        expect($el).to.equal(els[i]);
      });
    });
  });
});