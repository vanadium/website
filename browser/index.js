// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/* jshint newcap: false */

var _ = require('lodash');
var domready = require('domready');
var React = require('react');
var ReactDOM = require('react-dom');

var dom = require('./dom');
var Sidebar = React.createFactory(require('./sidebar'));
var Toc = React.createFactory(require('./toc'));

domready(function() {
  var sidebarEl = dom.find('.sidebar');
  if (sidebarEl) {
    ReactDOM.render(Sidebar({
      items: parseSidebarProps(dom.find('.sidebar-data'))
    }), sidebarEl);

    // Menu toggle, for small screens.
    var obfuscatorEl = dom.element('div');
    obfuscatorEl.classList.add('mdl-layout__obfuscator');
    dom.find('body').appendChild(obfuscatorEl);
    function showSidebar() {
      sidebarEl.classList.add('is-visible');
      obfuscatorEl.classList.add('is-visible');
    }
    function hideSidebar() {
      sidebarEl.classList.remove('is-visible');
      obfuscatorEl.classList.remove('is-visible');
    }
    obfuscatorEl.addEventListener('click', hideSidebar);
    dom.find('header .icon').addEventListener('click', showSidebar);
  }

  // Render table of contents if requested and there are headings.
  var el = dom.find('.toc');
  if (el) {
    var props = parseTocProps();
    if ((props.headings || []).length > 0) {
      ReactDOM.render(Toc(props), el);
    } else {
      el.parentNode.removeChild(el);
    }
  }

  // Init syntax highlighting.
  require('./highlight')();

  // Add copy-to-clipboard buttons to code blocks, but only for certain sections
  // of the site.
  var pathname = window.location.pathname;
  if (pathname.match(/(tutorials|installation|contributing|syncbase)/)) {
    require('./clipboard')();
  }

  // Run the scroll listener on landing page only. Other pages have the header
  // fixed.
  if (pathname === '/' || pathname === '/index.html') {
    var body = document.body;
    function onScroll() {
      if(body.scrollTop < 15) {
         body.classList.add('not-scrolled');
      } else {
         body.classList.remove('not-scrolled');
      }
    }
    onScroll();
    document.addEventListener('scroll', onScroll);
  }

  // Update img elements to display alt text in a figcaption.
  dom.all('main img').forEach(function(img) {
    var a = dom.element('a');
        a.setAttribute('href', img.src);
        a.setAttribute('target', '_blank');
        a.appendChild(img.cloneNode());

    var caption = dom.element('figcaption', img.alt);
    var figure = dom.element('figure');
        figure.appendChild(a);
        figure.appendChild(caption);

    img.parentNode.replaceChild(figure, img);
  });

  // Open external links in a new tab.
  var links = document.links;
  for (var i = 0; i < links.length; i++) {
    if (links[i].hostname !== window.location.hostname) {
      links[i].target = '_blank';
    }
  }
});

function parseSidebarProps(el) {
  return _.map(_.filter(dom.all(el, 'a'), function(a) {
    return a.parentNode === el;
  }), function(a) {
    var text = a.innerText;
    if (a.className !== 'nav') {
      return {text: text, href: a.href};
    }
    var nav = a.nextElementSibling;
    console.assert(nav.tagName === 'NAV');
    return {text: text, items: parseSidebarProps(nav)};
  });
}

function parseTocProps() {
  // Note, we ignore nested headers such as those inside info boxes.
  var hs = dom.all('main > h1, main > h2, main > h3, main > h4');
  var titleEl = _.find(hs, function(el) {
    return el.classList.contains('title');
  });
  var headings = [];
  _.forEach(hs, function(el) {
    if (el === titleEl || !el.id) {
      return;
    }
    headings.push({
      id: el.id,
      text: el.innerText,
      level: parseInt(el.tagName.split('')[1]),
      isAboveWindow: function() {
        return el.getBoundingClientRect().top < 0;
      },
      isBelowWindow: function() {
        return el.getBoundingClientRect().bottom > window.innerHeight;
      }
    });
  });
  return {
    title: titleEl.innerText,
    headings: headings
  };
}