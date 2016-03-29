# Vanadium website

This repository contains the source code for generating the static assets for
the Vanadium website.

## Directory structure

- `browser` - Client-side JS that executes when users visit the website
- `build` - Output location for `make build`
- `content` - Markdown content; gets converted to HTML by `haiku`
- `helpers.js` - JS used by `haiku` when rendering Markdown files
- `node_modules` - Disposable directory created by `npm install`
- `package.json` - Tells `npm install` what to install
- `public` - Static assets, copied directly into the `build` directory
- `stylesheets` - LESS stylesheets, compiled into CSS for the website
- `templates` - [Mustache] templates used by `haiku` for layouts and partials
- `tools` - Tools involved in generating the site's static assets

## Development

### Prerequisites

Install Vanadium per the installation instructions on the website. Also, install
the Node.js profile using `jiri profile install v23:nodejs`.

### Local development

You can make and view changes locally by running a development server:

    make serve

This command will print out a URL to visit in your browser. It will take a few
minutes to run the first time around, but subsequent invocations will be fast.

By default, the running server will not reflect subsequent changes to the
website content, since it's just serving the assets in the `build` directory.
Running `make build` will cause the server to see the new content. Better yet,
use the following command to automatically rebuild the assets whenever something
changes:

    make watch

This command requires the `entr` program, which can be installed on
Debian/Ubuntu using `apt-get install entr`, and on OS X using `brew install
entr`.

### Copy changes

Add or modify [Markdown]-formatted files in the `content` directory.

The `haiku` tool provides some extra flexibility on top of standard Markdown by
processing Mustache template variables. For example:

    = yaml =
    title: My Creative Title
    author: Alice
    = yaml =

    # {{ page.title }}

    Author: {{ page.author }}

A common editing workflow is to run `make watch`, edit Markdown files in a text
editor, and refresh the browser to see changes. If you prefer a WYSIWYG editing
experience, there are a number of options, e.g.:

- [Atom](https://atom.io/)
- [StackEdit](https://stackedit.io/)
- [Dillinger](http://dillinger.io/)

For new content, it's common to do initial drafting and editing in [Google
Docs], and to switch to Markdown at publication time.

### CSS and JS changes

The `make build` task generates `public/css/bundle.css` and
`public/js/bundle.js` from the files in `stylesheets` and `browser`
respectively. To modify the website CSS or JS, edit those files, then rebuild
the site (or use `make watch` to have your changes trigger rebuild).

## Deployment

Jenkins [automatically](https://veyron.corp.google.com/jenkins/job/vanadium-website-deploy/)
deploys to production on every successful build of
[vanadium-website-site](https://veyron.corp.google.com/jenkins/job/vanadium-website-site/) target.

[mustache]: http://mustache.github.io/
[markdown]: https://daringfireball.net/projects/markdown/
[google docs]: https://docs.google.com/
