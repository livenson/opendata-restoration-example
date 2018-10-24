#!/bin/sh

export JEKYLL_VERSION=3.8
export OPENDATA_GIT_REPO=https://github.com/keeganmcbride/jkan.git

if [ ! -d opendata-jkan ]
then
    git clone $OPENDATA_GIT_REPO opendata-jkan
else
    cd opendata-jkan
    git pull
fi

docker run --rm \
  --volume="$PWD/opendata-jkan:/srv/jekyll" \
  -it jekyll/jekyll:$JEKYLL_VERSION \
  jekyll build
