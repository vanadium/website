// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Test links which appear on the site.
var format = require('format');
var fs = require('graceful-fs');
var linkstream = require('./link-stream');
var path = require('path');
var powerwalk = require('powerwalk');
var pump = require('pump');
var test = require('tape');
var through = require('through2');

var build = path.resolve(__dirname, '../build');

test('inbound links', function(t) {
  var fileStream = powerwalk(build);
  var ls = linkstream();
  var ts = through.obj(write);

  // Called everytime the link-stream emits a "data" event.
  function write(data, enc, callback) {
    // HREF is the HTML attribute extracted from anchor tags with a
    // destination that links back into the site.
    var href = data.destination;
    // To aid in debugging, set 'source' to the original source of this link -
    // the Markdown page from which the HTML containing the link was
    // generated.
    var source = data.source
          .replace(build, './content')
          .replace('.html', '.md');
    var prefix = format('"%s" links to "%s" - ', source, href);

    t.equal(href[0], '/', format('%s should be absolute', prefix));

    // The linked destination should have a file in the build directory.
    var file = path.join(build, href);
    stat(file, function onstat(err, stats) {
      t.error(err, format('%s should exist', prefix));
      callback();
    });
  }

  // Pipe the three streams together using the pump module, passing t.end as
  // the final callback. The t.end method comes from the tape module and takes
  // a callback wich is fired when pump encounters an end-of-stream event
  // (either "end" or "error") anywhere in the pipeline.
  //
  // SEE: https://www.npmjs.com/package/pump
  pump(fileStream, ls, ts, function done(err) {
    t.error(err, 'streaming link pipeline should not error');
    t.end();
  });
});

function stat(pathname, callback) {
  fs.stat(pathname, function onstat(err, stats) {
    if (err) {
      callback(err);
      return;
    }

    if (stats.isDirectory()) {
      stat(path.join(pathname, 'index.html'), callback);
    } else {
      callback(null, stats);
    }
  });
}
