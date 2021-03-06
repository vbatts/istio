#!/bin/bash

# Init script downloads or updates envoy and the go dependencies.

ROOT=$(cd $(dirname $0)/..; pwd)
ISTIO_GO=$ROOT

set -o errexit
set -o nounset
set -o pipefail

# Set GOPATH to match the expected layout
GO_TOP=$(cd $(dirname $0)/../../../..; pwd)
OUT=${GO_TOP}/out

export GOPATH=${GOPATH:-$GO_TOP}

# Ensure expected GOPATH setup
if [ ${ROOT} != "${GO_TOP:-$HOME/go}/src/istio.io/istio" ]; then
       echo "Istio not found in GOPATH/src/istio.io/"
       exit 1
fi

which ${GO_TOP}/bin/dep >/dev/null || go get -u github.com/golang/dep/cmd/dep

# Download dependencies
if [ ! -d vendor/github.com ]; then
    ${GO_TOP}/bin/dep ensure -vendor-only
	cp Gopkg.lock vendor/Gopkg.lock
elif [ ! -f vendor/Gopkg.lock ]; then
    ${GO_TOP}/bin/dep ensure -vendor-only
	cp Gopkg.lock vendor/Gopkg.lock
else
    diff Gopkg.lock vendor/Gopkg.lock > /dev/null || \
            ( ${GO_TOP}/bin/dep ensure -vendor-only ; \
              cp Gopkg.lock vendor/Gopkg.lock)
fi

# Original circleci - replaced with the version in the dockerfile, as we deprecate bazel
#ISTIO_PROXY_BUCKET=$(sed 's/ = /=/' <<< $( awk '/ISTIO_PROXY_BUCKET =/' WORKSPACE))
#PROXYVERSION=$(sed 's/[^"]*"\([^"]*\)".*/\1/' <<<  $ISTIO_PROXY_BUCKET)
PROXYVERSION=$(grep envoy-debug pilot/docker/Dockerfile.proxy_debug  |cut -d: -f2)
PROXY=debug-$PROXYVERSION

# Save envoy in vendor, which is cached
if [ ! -f vendor/envoy-$PROXYVERSION ] ; then
    mkdir -p $OUT
    pushd $OUT
    curl -Lo - https://storage.googleapis.com/istio-build/proxy/envoy-$PROXY.tar.gz | tar xz
    cp usr/local/bin/envoy $ISTIO_GO/vendor/envoy-$PROXYVERSION
    popd
fi

if [ ! -f $GO_TOP/bin/envoy ] ; then
    cp $ISTIO_GO/vendor/envoy-$PROXYVERSION $GO_TOP/bin/envoy
fi

if [ ! -f ${ROOT}/pilot/proxy/envoy/envoy ] ; then
    ln -sf $GO_TOP/bin/envoy ${ROOT}/pilot/proxy/envoy
fi

