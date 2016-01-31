= yaml =
title: Detailed Installation
toc: true
sort: 2
= yaml =

Installation of Vanadium requires [bash], [curl], [Git][git] and the
[Go][go-install] programming language.

Optionally install:
 * [Node.js][node-install] - if you want to do JavaScript development.

# Bash

Installation and tutorial commands must run in a [bash] shell:
<!-- @mustHaveBash @test -->
```
set | grep BASH > /dev/null || echo "vanadium_install.sh: Not running in bash, this won't work\!"
```

# Environment variables

Decide on a directory to hold Vanadium code, and point the environment
variable `V23_RELEASE` at that directory.

The default setting below places the release in `$HOME/v23_release`,
but you can put it wherever you want.

<!-- @define_V23_RELEASE @test -->
```
[ -d "${HOME:?'Must define HOME'}" ]
export V23_RELEASE=$HOME/v23_release
```

{{# helpers.note }}
`$V23_RELEASE` is intended to point to the root of an end-user
(developer) release.  In contrast, `$JIRI_ROOT`, discussed in the
[contributor instructions], points to the root of a contributor tree,
a superset of the release.  See the [coding guidelines] for more
details.
{{/ helpers.note }}

The `go get` [procedure][go-get] used below for installation downloads
code from a git repository and puts it into a `src` subdirectory below
*the first directory* specified on `GOPATH`.

To allow for a clean uninstall leaving other Go stuff in place, we
suggest making `$V23_RELEASE` (the value of `V23_RELEASE`) the _only_ path on
`GOPATH` during the installation:

<!-- @defineGoPath @test -->
```
export GOPATH=$V23_RELEASE
```

# Prerequisite tools

Check for other prerequisite tools (in addition to bash):

<!-- @toolPrerequisites @test -->
```
vErrors=""
function vCheck() {
  local foo=`command -v $1 2>/dev/null`
  if [ "$foo" == "" ]; then
    vErrors="${vErrors}\n\nPlease install $1 version $2 or higher."
    if [ "$4" != "" ]; then
      vErrors="${vErrors}\n\tExample command for installation on ubuntu:\n\t\t$4"
    fi
    return
  fi
  local flag="version"
  if [ "$1" != "go" ]; then flag="--$flag"; fi
  local sedOp='-rn'
  case "`uname`" in
    # http://www.grymoire.com/Unix/Sed.html#uh-62k
    Darwin*) sedOp='-E' ;;
  esac
  local sedPa="s/$3/\1/p"
  local cmd="$1 $flag | head -n 1 | sed $sedOp '$sedPa'"
  local v=`eval "$cmd"`
  if [ "$v" \< "$2" ]; then
     vErrors="${vErrors}\nYou have $1 version $v; need version $2 or higher."
  fi
}

vCheck "curl" "5" "curl ([0-9])\..*" "sudo apt-get install curl"
# Git is used to download Vanadium software.
# Older versions of git might work, but we test at >=2.0
vCheck "git" "1.9" "git version ([0-9]+\.[0-9]+)\..*" "sudo apt-get install git"
vCheck "go" "1.5" ".* go([0-9\.]+) .*" "curl https://storage.googleapis.com/golang/go1.5.linux-amd64.tar.gz -o - | tar xzf -"
if [ "$vErrors" != "" ]; then
  echo " "
  echo -e $vErrors
  echo " "
  echo "Please install prerequisites before continuing."
fi
```

{{# helpers.hidden}}
<!-- @exitIfMissingPrerequisites @test -->
```
if [ "$vErrors" != "" ]; then
  exit 1
fi
```
{{/ helpers.hidden}}

# Optional tools

[Node.js][node-install] is required for JavaScript development.

<!-- @toolPrerequisitesNode @test -->
```
vCheck "node" "0.10" "v([0-9]+\.[0-9]+).*"
```

# Troubleshooting

If there were failures above, consult these operating-system dependent
instructions:

* [Linux][linux]
* [OS X][os-x]

# Install Vanadium

Use `go get` to put Vanadium into the first directory on your
`GOPATH` (it should match the value of `V23_RELEASE`):

<!-- @installVanadium @test -->
```
/bin/rm -rf $V23_RELEASE
mkdir -p $V23_RELEASE
# The following downloads Vanadium Go code below $GOPATH.
function buildV23() {
  go get -d v.io/x/ref/...

  # Install specific CLI dependencies for the tutorials without hitting the
  # leveldb dependency in v.io/x/ref/services/groups/...
  #
  # This is a short-term solution until a simpler method of negotiating non-go
  # dependencies can be decided and resolved.
  #
  # SEE: https://github.com/vanadium/issues/issues/586
  go install v.io/x/ref/cmd/...
  go install v.io/x/ref/services/agent/...
  go install v.io/x/ref/services/mounttable/...
}

NATTEMPTS=3
for attempt in $(seq 1 "${NATTEMPTS}"); do
  buildV23 && break
  if [[ "${attempt}" == "${NATTEMPTS}" ]]; then
    echo -e "\n\n"
    echo "v23 installation failed ${NATTEMPTS} times in a row."
    echo "This can happen when our repository servers are"
    echo "temporarily unavailable. Please try again later."
    exit 1
  fi
  echo "\"v23 update\" failed, trying again."
done

```

Installation takes about five minutes.

The first two commands ensure that `$V23_RELEASE` holds a clean install.
The `go get` command downloads the core Vanadium code and installs it
by compiling binaries to `$V23_RELEASE/bin`.

__That's it!__

You are ready to start using Vanadium or continue with the
[tutorials].

{{# helpers.note }}

#### Optional install verification:

* Run an arbitrary unit test.
  ```bash
  go test v.io/v23/security
  ```

* See the help text from a core Vanadium binary.
  ```bash
  $V23_RELEASE/bin/principal help
  ```

* Serve Go documentation.
  ```bash
  godoc --http :8080
  ```

This command puts up a webserver.  To see, for
example, some security code visit
[http://localhost:8080/pkg/v.io/v23/security](http://localhost:8080/pkg/v.io/v23/security).
You may have to replace *localhost* with the output of the `hostname`
command to see the correct web page.

{{/ helpers.note }}

# Uninstall Vanadium

If you followed the instructions above to put Vanadium into a new
directory called `$V23_RELEASE`, you can uninstall Vanadium by deleting
that directory.

{{# helpers.warning }}
#### This wipes what you did above!

```bash
/bin/rm -rf $V23_RELEASE
```
{{/ helpers.warning }}

[coding guidelines]: /community/coding-guidelines.html#code-organization
[contributor instructions]: /community/contributing.html#v23_root-environment-variable
[curl]: http://curl.haxx.se/download.html
[git]: http://git-scm.com/
[go-get]: https://golang.org/cmd/go/#hdr-Download_and_install_packages_and_dependencies
[go-install]: http://golang.org/doc/install
[linux]: /installation/linux.html
[node-install]: http://nodejs.org/download/
[os-x]: /installation/os-x.html
[tutorials]: /tutorials/hello-world.html
[vanadium-source]: https://vanadium.googlesource.com
[bash]: /tutorials/faq.html#why-bash-
