// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Like querySelectorAll, but returns an array instead of a NodeList.
exports.all = function(el, selectors) {
  if (typeof el === 'string') {
    selectors = el;
    el = document;
  }
  var nodeList = el.querySelectorAll(selectors);
  var arr = [];
  for (var i = 0; i < nodeList.length; i++) {
    arr.push(nodeList[i]);
  }
  return arr;
};

// Like querySelector.
exports.find = function(el, selectors) {
  if (typeof el === 'string') {
    selectors = el;
    el = document;
  }
  return el.querySelector(selectors);
};

// Creates an element.
exports.element = function(name, attributes, text) {
  if (typeof attributes === 'string') {
    text = attributes;
    attributes = {};
  } else {
    attributes = attributes || {};
  }
  var el = document.createElement(name);
  Object.keys(attributes).forEach(function(name) {
    el.setAttribute(name, attributes[name]);
  });
  if (text) {
    el.textContent = text;
  }
  return el;
};
