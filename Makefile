SHELL := /bin/bash -euo pipefail
PATH := node_modules/.bin:$(PATH)
MDRIP ?= $(JIRI_ROOT)/third_party/go/bin/mdrip

# Add node/npm to PATH.
NODE_DIR := $(shell jiri v23-profile list --info Target.InstallationDir nodejs)
export PATH := $(NODE_DIR)/bin:$(PATH)

# TODO(sadovsky):
# - Add "site-test" unit tests
# - "identity" subdir (needed by identity service?)
# - deploy-production rule

define BROWSERIFY
	@mkdir -p $(dir $2)
	browserify $1 -d -o $2
endef

.DELETE_ON_ERROR:
.DEFAULT_GOAL := build

node_modules: package.json
	npm prune
	npm install
	touch $@

.PHONY: hljs
hljs: node_modules
	cp node_modules/highlight.js/styles/github.css public/css

.PHONY: mdl
mdl: node_modules
	cp node_modules/material-design-lite/material*css* public/css
	cp node_modules/material-design-lite/material*js* public/js

# NOTE(sadovsky): Newer versions of postcss-cli and autoprefixer use JavaScript
# Promises, which doesn't work with Vanadium's old version of node, 0.10.24.
public/css/bundle.css: $(shell find stylesheets) node_modules
	lessc -sm=on stylesheets/index.less | postcss -u autoprefixer > $@

public/js/bundle.js: browser/index.js $(shell find browser) node_modules
	$(call BROWSERIFY,$<,$@)

################################################################################
# Build, serve, and deploy

build: $(MDRIP) node_modules hljs mdl public/css/bundle.css public/js/bundle.js gen-scripts
	haiku build --helpers helpers.js --build-dir $@

.PHONY: serve
serve: build
	@static build -H '{"Cache-Control": "no-cache, must-revalidate"}'

TMPDIR := $(shell mktemp -d "/tmp/XXXXXX")
HEAD := $(shell git rev-parse HEAD)

# TODO(sadovsky): Check that we're in a clean master branch. Also, automate
# deployment so that changes are picked up automatically.
.PHONY: deploy
deploy: clean build
	git clone git@github.com:vanadium/vanadium.github.io.git $(TMPDIR)
	rm -rf $(TMPDIR)/*
	rsync -r build/* $(TMPDIR)
	cd $(TMPDIR) && git add -A && git commit -m 'pull $(HEAD)' && git push

################################################################################
# Clean and lint

.PHONY: clean
clean:
	rm -rf build node_modules public/**/bundle.* public/sh public/tutorials

.PHONY: lint banned_words
lint: banned_words node_modules
	jshint .

# A list of case-sensitive banned words.
BANNED_WORDS := Javascript node.js Oauth
.PHONY: banned_words
banned_words:
	@for WORD in $(BANNED_WORDS); do \
		if [ -n "`grep -rn "$$WORD" content templates`" ]; then \
		  echo "`grep -rn "$$WORD" content templates`"; \
		  echo "Found banned word (case-sensitive): $$WORD"; \
		  exit 1; \
		fi \
	done

################################################################################
# Tutorial script generation and tests

install_md = installation/step-by-step.md
install_sh = public/sh/vanadium-install.sh

tutSetup       = tutorials/setup
tutCheckup     = tutorials/checkup
tutCleanup     = tutorials/cleanup
tutWipeSlate   = tutorials/wipe-slate
tutHello       = tutorials/hello-world
tutBasics      = tutorials/basics
tutPrincipals  = tutorials/security/principals-and-blessings
tutPermsAuth   = tutorials/security/permissions-authorizer
tutCaveats1st  = tutorials/security/first-party-caveats
tutCaveats3rd  = tutorials/security/third-party-caveats
tutAgent       = tutorials/security/agent
tutCustomAuth  = tutorials/security/custom-authorizer
tutMountTable  = tutorials/naming/mount-table
tutNamespace   = tutorials/naming/namespace
tutSuffixPart1 = tutorials/naming/suffix-part1
tutSuffixPart2 = tutorials/naming/suffix-part2
tutGlobber     = tutorials/naming/globber
tutJSHello     = tutorials/javascript/hellopeer
tutJSFortune   = tutorials/javascript/fortune
tutJavaAndroid = tutorials/java/android
tutJavaFortune = tutorials/java/fortune

# Scripts that 'complete' the named tutorials, creating all relevant files
# (code, credentials, etc.) but skipping ephemeral steps like starting servers,
# running clients, etc. Such scripts need exist only for tutorials that create
# such files.
completer = public/sh/tut-completer
completerScripts = \
	$(completer)-hello-world.sh \
	$(completer)-basics.sh \
	$(completer)-permissions-authorizer.sh \
	$(completer)-custom-authorizer.sh \
	$(completer)-suffix-part1.sh \
	$(completer)-suffix-part2.sh \
	$(completer)-globber.sh \
	$(completer)-js-hellopeer.sh \
	$(completer)-js-fortune.sh

# Opaquely named copies of particular completer scripts, used to set up
# conditions for later tutorials. See individual targets for more explanation.
scenario = public/sh/scenario
setupScripts = \
	$(install_sh) \
	$(scenario)-a-setup.sh \
	$(scenario)-b-setup.sh \
	$(scenario)-c-setup.sh \
	$(scenario)-d-setup.sh \
	$(scenario)-e-setup.sh \
	$(scenario)-f-setup.sh

# This target builds the hosted web assets for the JavaScript tutorials.
jsTutorialResults := public/tutorials/javascript/results

# Install mdrip if needed.
$(MDRIP):
	jiri go install github.com/monopole/mdrip

# Vanadium install script.
# This can be run as a prerequisite for tutorial setup.
$(install_sh): content/$(install_md) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 3 test $^ > $@

# Targets of the form $(scenario)-{x}-setup.sh create scripts that are meant to
# be run by a user as an argument to 'source', so that they modify the user's
# active environment. They are prerequisite to particular tutorials.
#
# Each script has two sections: a preamble that should run error-free, setting
# env vars and defining shell functions, and a general section that runs as a
# subshell, capable of exiting on error. Error exits from a subshell won't close
# the terminal that issued the 'source' command.
#
# The preamble section is generated from the contents of the first filename
# argument to "$(MDRIP) --preambled". The remaining arguments define the
# subshell code. Code to verify setup and exit if something went wrong should
# appear in the subshell, not in the preamble.
$(scenario)-a-setup.sh: \
	content/$(tutSetup).md \
	content/$(tutCheckup).md | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsCommon = \
	content/$(tutSetup).md \
	content/$(tutCheckup).md \
	content/$(tutWipeSlate).md

# Targets of the from test-{tutorial-name} are meant for interactive use to test
# an individual tutorial and/or extract the code associated with said tutorial.
# The code winds up in $V_TUT/src, where $V_TUT is defined in tutSetup.

depsHello = $(depsCommon) content/$(tutHello).md
.PHONY: test-hello-world
test-hello-world: $(depsHello) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-hello-world.sh: $(depsHello) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsBasics = $(depsCommon) content/$(tutBasics).md
.PHONY: test-basics
test-basics: $(depsBasics) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-basics.sh: $(depsBasics) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@
$(scenario)-b-setup.sh: $(completer)-basics.sh
	cp $^ $@

depsPrincipals = $(depsBasics) content/$(tutPrincipals).md
.PHONY: test-principals
test-principals: $(depsPrincipals) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(scenario)-c-setup.sh: $(depsPrincipals) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsPermsAuth = $(depsPrincipals) content/$(tutPermsAuth).md
.PHONY: test-permissions-authorizer
test-permissions-authorizer: $(depsPermsAuth) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-permissions-authorizer.sh: $(depsPermsAuth) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@
$(scenario)-d-setup.sh: $(completer)-permissions-authorizer.sh
	cp $^ $@

depsMultiDisp = $(depsPermsAuth) content/$(tutSuffixPart1).md
.PHONY: test-multiservice-dispatcher
test-multiservice-dispatcher: $(depsMultiDisp) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-multiservice-dispatcher.sh: $(depsMultiDisp) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@
$(scenario)-f-setup.sh: $(completer)-multiservice-dispatcher.sh
	cp $^ $@

depsCaveats1st = $(depsPermsAuth) content/$(tutCaveats1st).md
.PHONY: test-caveats-1st
test-caveats-1st: $(depsCaveats1st) | $(MDRIP)
	$(MDRIP) --subshell test $^

depsCaveats3rd = $(depsPermsAuth) content/$(tutCaveats3rd).md
.PHONY: test-caveats-3rd
test-caveats-3rd: $(depsCaveats3rd) | $(MDRIP)
	$(MDRIP) --subshell test $^

depsAgent = $(depsPermsAuth) content/$(tutAgent).md
.PHONY: test-agent
test-agent: $(depsAgent) | $(MDRIP)
	$(MDRIP) --subshell test $^

depsCustomAuth = $(depsPermsAuth) content/$(tutCustomAuth).md
.PHONY: test-custom-auth
test-custom-auth: $(depsCustomAuth) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-custom-authorizer.sh: $(depsCustomAuth) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsMountTable = $(depsBasics) content/$(tutMountTable).md
.PHONY: test-mount-table
test-mount-table: $(depsMountTable) | $(MDRIP)
	$(MDRIP) --subshell test $^

depsNamespace = $(depsBasics) content/$(tutNamespace).md
.PHONY: test-namespace
test-namespace: $(depsNamespace) | $(MDRIP)
	$(MDRIP) --subshell test $^

depsSuffixPart1 = $(depsBasics) content/$(tutSuffixPart1).md
.PHONY: test-suffix-part1
test-suffix-part1: $(depsSuffixPart1) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-suffix-part1.sh: $(depsSuffixPart1) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsSuffixPart2 = $(depsMultiDisp) content/$(tutSuffixPart2).md
.PHONY: test-suffix-part2
test-suffix-part2: $(depsSuffixPart2) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-suffix-part2.sh: $(depsSuffixPart2) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsGlobber = $(depsMultiDisp) content/$(tutGlobber).md
.PHONY: test-globber
test-globber: $(depsGlobber) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-globber.sh: $(depsGlobber) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

depsJsHello = $(depsBasics) content/$(tutJSHello).md
.PHONY: test-js-hello
test-js-hellopeer: $(depsJsHello) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-js-hellopeer.sh: $(depsJsHello) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@
$(scenario)-e-setup.sh: $(completer)-js-hellopeer.sh
	cp $^ $@

depsJsFortune = $(depsBasics) content/$(tutJSFortune).md
.PHONY: test-js-fortune
test-js-fortune: $(depsJsFortune) | $(MDRIP)
	$(MDRIP) --subshell test $^
$(completer)-js-fortune.sh: $(depsJsFortune) | $(MDRIP)
	mkdir -p $(@D)
	$(MDRIP) --preambled 0 completer $^ > $@

# An ordering that lets us test all the tutorials faster than running the
# individual tests in sequence. This exploits the knowledge that, for example,
# tutCaveats3rd can be tested right after tutCaveats1st without reseting to a
# clean slate. WipeSlate and Basics are done where needed to reset state.
depsOneBigCoreTutorialTest = \
	content/$(tutSetup).md \
	content/$(tutCheckup).md \
	content/$(tutWipeSlate).md \
	content/$(tutHello).md \
	content/$(tutBasics).md \
	content/$(tutPrincipals).md \
	content/$(tutPermsAuth).md \
	content/$(tutCaveats1st).md \
	content/$(tutCaveats3rd).md \
	content/$(tutAgent).md \
	content/$(tutCustomAuth).md \
	content/$(tutWipeSlate).md \
	content/$(tutBasics).md \
	content/$(tutMountTable).md \
	content/$(tutNamespace).md \
	content/$(tutWipeSlate).md \
	content/$(tutBasics).md \
	content/$(tutPrincipals).md \
	content/$(tutPermsAuth).md \
	content/$(tutSuffixPart1).md \
	content/$(tutSuffixPart2).md

# An ordering that lets us test all the JS tutorials faster than running the
# individual tests in sequence.
depsOneBigJsTutorialTest = \
	content/$(tutSetup).md \
	content/$(tutCheckup).md \
	content/$(tutWipeSlate).md \
	content/$(tutBasics).md \
	content/$(tutJSHello).md \
	content/$(tutJSFortune).md

# An ordering that lets us test all the Java tutorials faster than running the
# individual tests in sequence.
depsOneBigJavaTutorialTest = \
	content/$(tutJavaFortune).md \
	content/$(tutJavaAndroid).md

.PHONY: test
test: test-site test-tutorials-core test-tutorials-js-node test-tutorials-java

.PHONY: test-site
test-site: build

# Test core tutorials against an existing development install.
#
# This is the target to run to see if the tutorials work against Vanadium
# changes that have not been checked in.
#
# Called from v.io/x/devtools/jiri-test/internal/test/website.go.
# This test fails if JIRI_ROOT isn't defined.
# This test defines V_TUT (a tutorial variable) appropriately in terms of
# JIRI_ROOT.
.PHONY: test-tutorials-core
test-tutorials-core: build
	jiri go install v.io/v23/... v.io/x/ref/...
	$(MDRIP) --subshell --blockTimeOut 1m test content/testing.md $(depsOneBigCoreTutorialTest)


# Test Java tutorials.
.PHONY: test-tutorials-java
test-tutorials-java: build
	$(MDRIP) --blockTimeOut 5m --subshell test $(depsOneBigJavaTutorialTest)

# Test JS tutorials against an existing development install.
#
# This is the target to run to see if the tutorials work against Vanadium
# changes that have not been checked in.
#
# Note: Unlike test-tutorials-js-web, this test is intended to skip the UI
# portion of the test in order to achieve some amount of test coverage without
# having to introduce additional dependencies.
#
# Called from v.io/x/devtools/jiri-test/internal/test/website.go.
# This test fails if JIRI_ROOT isn't defined.
# This test defines V_TUT (a tutorial variable) appropriately in terms of
# JIRI_ROOT.
.PHONY: test-tutorials-js-node
test-tutorials-js-node: build
	jiri go install v.io/v23/... v.io/x/ref/...
	$(MDRIP) --blockTimeOut 2m --subshell test content/testing.md $(depsOneBigJsTutorialTest)

# Test JS tutorials (web version) against an existing development install.
#
# This is the target to run to see if the tutorials work against Vanadium
# changes that have not been checked in.
#
# However, it uses the live version of the Vanadium extension.
#
# Used to be called from v.io/x/devtools/jiri-test/internal/test/website.go.
# This test fails if JIRI_ROOT isn't defined.
#
# This test also takes additional env vars (typically temporary):
# - GOOGLE_BOT_USERNAME and GOOGLE_BOT_PASSWORD (to sign into Google/Chrome)
# - CHROME_WEBDRIVER (the path to the Chrome WebDriver)
# - WORKSPACE (optional, defaults to $JIRI_ROOT/website)
#
# In addition, this test requires Maven and Xvfb and xvfb-run to be installed.
# An HTML report is written to $JIRI_ROOT/website/htmlReports.
#
# NOTE(sadovsky): This test does not currently work, is omitted from continuous
# integration testing, and will likely be decommissioned soon.
.PHONY: test-tutorials-js-web
test-tutorials-js-web: build
	jiri go install v.io/v23/... v.io/x/ref/...
	$(MDRIP) --subshell --blockTimeOut 3m testui content/testing.md $(depsOneBigJsTutorialTest)

# Test tutorials against fresh external install.
#
# This runs an install from v.io, then runs the tutorials against that install,
# exactly as an external user would run them. Local changes of Vanadium have no
# impact on this test. This test does not require definition of JIRI_ROOT; it
# uses V23_RELEASE instead, per the installation instructions on the external
# site.
.PHONY: test-tutorials-external
test-tutorials-external: build
	$(MDRIP) --subshell --blockTimeOut 10m test content/$(install_md) $(depsOneBigCoreTutorialTest)

# Test tutorials without install. Assumes JIRI_ROOT and V23_RELEASE are defined.
#
# This runs tests without first doing any installation step, and assumes
# JIRI_ROOT and V23_RELEASE are properly defined. It's a time saver if you are
# happy with your installation and are just debugging tutorial code.
.PHONY: test-tutorials-no-install
test-tutorials-no-install: build
	$(MDRIP) --subshell test $(depsOneBigCoreTutorialTest)

# The files needed to build JS tutorial output.
depsJSTutorialResults = \
	content/testing.md \
	content/$(tutSetup).md \
	content/$(tutBasics).md \
	content/$(tutJSHello).md \
	content/$(tutJSFortune).md

# There are two steps to this build target:
# 1. Build any dependencies like the VDL tool.
# 2. Run mdrip to create artifacts from running $(jsDeps) code blocks.
#
# NOTE: Jenkins nodes may use the $JIRI_ROOT installation rather than "go get".
# The "jiri go install" line below ensures all required tools (e.g. vdl) are
# installed.
$(jsTutorialResults): $(depsJSTutorialResults) | $(MDRIP)
	jiri go install v.io/v23/... v.io/x/ref/...
	V_TUT=$(abspath $@) $(MDRIP) --subshell --blockTimeOut 1m buildjs $^
	rm -rf $(abspath $@)/node_modules

.PHONY: gen-scripts
gen-scripts: $(completerScripts) $(setupScripts) $(jsTutorialResults)
