#!/usr/bin/env bash

set -euo pipefail

readonly DIR=${1}
mkdir -p ${DIR}

get() {
  local -r NAME=${1}
  local -r URL=${2}
  curl -L -o ${DIR}/${NAME} ${URL}
}

get react-0.14.3.min.js https://fb.me/react-0.14.3.min.js
get react-dom-0.14.3.min.js https://fb.me/react-dom-0.14.3.min.js
get react-0.14.3.js https://fb.me/react-0.14.3.js
get react-dom-0.14.3.js https://fb.me/react-dom-0.14.3.js
