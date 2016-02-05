// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Returns a stream that consumes filenames corresponding to HTML pages, and
// emits anchor urls extracted from these HTML pages. Emits any given url at
// most once. Strips fragments from urls, and does not emit fragment-only
// URLs.
var cheerio = require('cheerio');
var fs = require('graceful-fs');
var path = require('path');
var through = require('through2');

module.exports = create;

function create() {
  return through.obj(write);

  // Called every-time a file is emitted from the powerwalk stream.
  function write(buffer, enc, callback) {
    var stream = this;
    var file = buffer.toString();

    // Do not scrape non-html files.
    if (path.extname(file) !== '.html') {
      callback();
      return;
    }

    fs.readFile(file, function ondata(err, data) {
      if (err) {
        callback(err);
        return;
      }

      // Scrape links.
      var $ = cheerio.load(data);
      $('a').each(function(i, element) {
        var href = $(element).attr('href') || '';
        // Remove trailing fragements.
        href = href.replace(/html#(.*)/, 'html');
        var isFragement = !!href.match(/^#/);

        // Filter out any empty hrefs, or if the href is only an anchor tag (a
        // link to a heading in the current document).
        if (!href || isFragement) {
          return;
        }

        // Ignore external links.
        // NOTE: This could be made as an option if there is a need to test
        // outbound links.
        var isExternal = !!href.match(/^http/);
        if (isExternal && !stream._external) {
          return;
        }

        stream.push({
          destination: href,
          source: file
        });
      });

      callback();
    });
  }
}
