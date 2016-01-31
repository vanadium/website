// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

var _ = require('lodash');
var React = require('react');

exports.h = function(selector, props, children) {
  if (_.isPlainObject(props)) {
    console.assert(!props.id && !props.className);
  } else {
    children = props;
    props = {};
  }
  var parts = selector.split('.');
  var x = parts[0].split('#'), tagName = x[0], id = x[1];
  var className = parts.slice(1).join(' ');
  console.assert(tagName);
  props = _.assign({}, props, {
    id: id || undefined,
    className: className || undefined
  });
  return React.createElement(tagName, props, children);
};
