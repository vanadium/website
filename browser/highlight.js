// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

var hljs = require('highlight.js');

function language(name) {
  return function() {
    var l = hljs.getLanguage(name);
    l.contains.push({className: 'catline', begin: 'cat', end: '$'});
    l.contains.push({className: 'eofline', begin: 'EOF', end: '$'});
    return l;
  };
}

module.exports = function() {
  hljs.registerLanguage('vjs', language('javascript'));
  hljs.registerLanguage('vxml', language('xml'));
  hljs.configure({languages: ['bash', 'go', 'vjs', 'vxml']});
  hljs.initHighlighting();
};
