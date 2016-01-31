// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

var _ = require('lodash');
var React = require('react');

var h = require('./util').h;

// Expects props {title, headings []Heading}, where Heading is
// {id, text, level, isAboveWindow, isBelowWindow}.
module.exports = React.createClass({
  displayName: 'Toc',
  getInitialState: function() {
    return _.assign({
      minLevel: _.min(_.map(this.props.headings, 'level'))
    }, this.props);
  },
  handleHashChange: function(e) {
    this.setState(function(state) {
      _.forEach(state.headings, function(heading) {
        heading.active = ('#' + heading.id) === window.location.hash;
      });
    });
  },
  handleScroll: function(e) {
    this.setState(function(state) {
      var i = 0, l = state.headings.length;
      for (; i < l; i++) {
        if (!state.headings[i].isAboveWindow()) {
          break;
        }
        if ((i + 1 === l) || state.headings[i + 1].isBelowWindow()) {
          break;
        }
      }
      for (var j = 0; j < l; j++) {
        state.headings[j].active = i === j;
      }
    });
  },
  componentDidMount: function() {
    window.addEventListener('hashchange', this.handleHashChange);
    window.addEventListener('resize', this.handleScroll);
    window.addEventListener('scroll', this.handleScroll);
    // Initialize active heading.
    this.handleScroll();
  },
  componentWillUnmount: function() {
    window.removeEventListener('hashchange', this.handleHashChange);
    window.removeEventListener('resize', this.handleScroll);
    window.removeEventListener('scroll', this.handleScroll);
  },
  render: function() {
    var props = this.props, state = this.state;
    return h('div', [
      h('div.title', props.title),
      h('div', _.map(props.headings, function(heading) {
        var gap = heading.level - state.minLevel;
        return h('a.heading' + (heading.active ? '.active' : ''), {
          href: '#' + heading.id,
          style: {
            marginLeft: (12 * gap) + 'px',
            fontSize: gap > 0 ? '13px' : '14px'
          }
        }, heading.text);
      }))
    ]);
  }
});
