// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/* jshint newcap: false */

var _ = require('lodash');
var React = require('react');
var ReactDOM = require('react-dom');

var dom = require('./dom');
var h = require('./util').h;

// For parsing nav urls.
var parser = document.createElement('a');

function isActive(href) {
  parser.href = href;
  return parser.pathname === window.location.pathname;
}

function hasActiveItem(items) {
  return _.some(items, function(item) {
    if (item.items) {
      return hasActiveItem(item.items);
    } else {
      return isActive(item.href);
    }
  });
}

var Link = React.createFactory(React.createClass({
  displayName: 'Link',
  render: function() {
    var props = this.props;
    return h('a' + (isActive(props.href) ? '.active' : ''), {
      href: props.href
    }, props.text);
  }
}));

var Nav = React.createFactory(React.createClass({
  displayName: 'Nav',
  getInitialState: function() {
    return _.assign({open: hasActiveItem(this.props.items)}, this.props);
  },
  componentDidMount: function() {
    var el = ReactDOM.findDOMNode(this);
    this.setState(function(state) {
      state.open = Boolean(dom.find(el, 'a.active'));
    });
  },
  render: function() {
    var that = this, state = this.state;
    return h('div', [
      h('a.nav', {
        href: '#',
        onClick: function() {
          that.setState(function(state) {
            state.open = !state.open;
          });
        }
      }, state.text),
      h('nav', {
        style: {
          height: state.open ? 'auto' : 0
        }
      }, renderItems(state.items))
    ]);
  }
}));

function renderItems(items) {
  return _.map(items, function(item) {
    if (item.items) {
      return Nav(item);
    } else {
      return Link(item);
    }
  });
}

function renderLogo(subsite) {
  var title;
  var href;
  if (subsite === 'syncbase') {
    title = 'Syncbase';
    href = '/syncbase';
  } else {
    title = 'Core';
    href = '/core.html';
  }

  return h('div.logo-row', [
    h('div.icon.v-icon', {},
      h('a', {href: '/'},
        h('img', {
          src: '/images/v-icon-cyan-700.svg'
        })
      )
    ),
    h('div.logo', {},
      h('a', {href: href}, title)
    )
  ]);
}

// Expects props {items []Item}, where Item is either {text, items []Item} or
// {text, href}.
module.exports = React.createClass({
  displayName: 'Sidebar',
  render: function() {
    return h('div', [
      renderLogo(this.props.subsite),
      h('div.items', renderItems(this.props.items))
    ]);
  }
});
