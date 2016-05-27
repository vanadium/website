// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

var marked = require('marked');

// Omits the given text.
exports.hidden = function(text) {
  return '';
};

// Creates an info block.
exports.info = function(text) {
  return '<div class="note info">' + marked(unindent(text)) + '</div>\n';
};

// Creates a warning block.
exports.warning = function(text) {
  return '<div class="note warning">' + marked(unindent(text)) + '</div>\n';
};

// Creates a code block with no copy-to-clipboard button.
exports.code = function(text) {
  return mkcode(text, 'noclipboard');
};

// Creates a code block with no copy-to-clipboard button and no syntax
// highlighting.
exports.codeoutput = function(text) {
  return mkcode(text, 'noclipboard nohighlight');
};

// Dims enclosed code when used within a code block.
exports.codedim = function(text) {
  text = text.replace(/^\n+|\s+$/g, '');
  return '<dim><dim-children>' + text + '</dim-children></dim>\n';
};

////////////////////////////////////////
// Internal helpers

// Used by code and codeoutput.
function mkcode(text, className) {
  // Drop any leading or trailing whitespace.
  text = text.replace(/^\s+|\s+$/g, '');
  return '<pre><code class="' + className + '">' + text + '</code></pre>\n';
}

// Removes leading tabs and spaces from lines in text.
function unindent(text) {
  return text.replace(/^[ \t]+/gm, '');
}
