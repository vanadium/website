// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

var hljs = require('highlight.js');

function language(name) {
  return function() {
    var l = hljs.getLanguage(name);
    l.contains.push({className: 'catline', begin: '^cat', end: '\n'});
    l.contains.push({className: 'eofline', begin: '^EOF', end: '\n'});
    l.contains.push({
      className: 'code-dim',
      begin: '{#dim}',
      end: '{/dim}',
      contains: [{
        className: 'code-dim-children',
        begin: '{#dim-children}',
        end: '{/dim-children}',
        excludeEnd: true,
        excludeBegin: true,
        contains: l.contains
      }]
    });
    return l;
  };
}

module.exports = function() {
  // Extend every supported language with code dimming functionality.
  hljs.registerLanguage('vxml', language('xml'));
  hljs.registerLanguage('vjava', language('java'));
  hljs.registerLanguage('vgo', language('go'));
  hljs.registerLanguage('vbash', language('bash'));
  hljs.configure({languages: ['vbash', 'vgo', 'vxml', 'vjava']});
  hljs.initHighlighting();
};
