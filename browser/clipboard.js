// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/* jshint newcap: false */

var _ = require('lodash');
var React = require('react');
var ReactDOM = require('react-dom');

var dom = require('./dom');
var h = require('./util').h;

function copy(text) {
  var pre = dom.element('pre');
  pre.style.position = 'absolute';
  pre.style.left = '-10000px';
  pre.textContent = text;

  document.body.appendChild(pre);
  var selection = window.getSelection();
  selection.removeAllRanges();
  var range = document.createRange();
  range.selectNodeContents(pre);
  selection.addRange(range);
  document.execCommand('copy');
  selection.removeAllRanges();
  document.body.removeChild(pre);
}

var Clipboard = React.createFactory(React.createClass({
  getInitialState: function() {
    return {
      status: '',
      t: Date.now()  // time of last setState
    };
  },
  render: function() {
    var that = this;
    return h('div.clipboard', [
      h('div.status', this.state.status),
      h('div.icon', {
        onMouseEnter: function() {
          that.setState({status: 'copy', t: Date.now()});
        },
        onMouseLeave: function() {
          that.setState({status: '', t: Date.now()});
        },
        onClick: function() {
          copy(that.props.text);
          var now = Date.now();
          that.setState({status: 'copied', t: now});
          window.setTimeout(function() {
            if (that.state.t === now) {
              that.setState({status: '', t: Date.now()});
            }
          }, 3000);  // 3 seconds
        }
      }, h('i.material-icons', 'content_paste'))
    ]);
  }
}));

module.exports = function() {
  _.forEach(dom.all('pre > code:not(.noclipboard)'), function(el) {
    var cbEl = dom.element('div');
    el.parentNode.insertBefore(cbEl, el);
    ReactDOM.render(Clipboard({text: el.innerText + '\n'}), cbEl);
  });
};
