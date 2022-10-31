#!/bin/bash

set -e

if [ -n "${GITHUB_HEAD_REF}" ]; then
  BRANCH="${GITHUB_HEAD_REF}"
else
  BRANCH="${GITHUB_REF#refs/heads/}"
fi

echo "Detected branch: ${BRANCH}"

if [ -n "${IS_FORK}" ]; then
  echo "Branch is from a fork"
  IS_FORK=true
else
  echo "Branch is from the savonet organization"
  IS_FORK=
fi

if [ "${IS_FORK}" != "true" ] && [[ "${BRANCH}" =~ "rolling-release-" ]] || [[ "${BRANCH}" =~ ^v[0-9] ]]; then
  echo "Branch is release branch"
  IS_RELEASE=true

  echo "Building on all architectures"
  BUILD_OS='["debian_bookworm", "debian_bullseye", "ubuntu_jammy", "ubuntu_focal", "alpine"]'
  BUILD_PLATFORM='["amd64", "arm64", "armhf"]'
  BUILD_INCLUDE='[{"platform": "amd64", "runs-on": "ubuntu-latest", "alpine-arch": "x86_64", "docker-platform": "linux/amd64"}, {"platform": "arm64", "runs-on": "self-hosted", "alpine-arch": "aarch64", "docker-platform": "linux/arm64"}, {"platform": "armhf", "runs-on": "self-hosted", "alpine-arch": "armv7", "docker-platform": "linux/arm/v7"}]'

  echo "Enabling opam build"
  echo "build_opam=true" >> $GITHUB_OUTPUT

  echo "Branch has a docker release"
  DOCKER_RELEASE=true
else
  echo "Branch is not release branch"
  IS_RELEASE=

  echo "Building on amd64 only"
  BUILD_OS='["debian_bookworm", "debian_bullseye", "ubuntu_jammy", "ubuntu_focal", "alpine"]'
  BUILD_PLATFORM='["amd64"]'
  BUILD_INCLUDE='[{"platform": "amd64", "runs-on": "ubuntu-latest", "alpine-arch": "x86_64", "docker-platform": "linux/amd64"}]'

  echo "Not enabling opam build"
  echo "Branch does not have a docker release"
  DOCKER_RELEASE=
fi

SHA=$(git rev-parse --short HEAD)

if [[ "${BRANCH}" =~ "rolling-release-" ]]; then
  echo "Branch is rolling release"
  IS_ROLLING_RELEASE=true
else
  IS_ROLLING_RELEASE=
fi

echo "branch=${BRANCH}" >> $GITHUB_OUTPUT
echo "is_release=${IS_RELEASE}" >> $GITHUB_OUTPUT
echo "build_os=${BUILD_OS}" >> $GITHUB_OUTPUT
echo "platform=${BUILD_PLATFORM}" >> $GITHUB_OUTPUT
echo "build_include=${BUILD_INCLUDE}" >> $GITHUB_OUTPUT
echo "docker_release=${DOCKER_RELEASE}" >> $GITHUB_OUTPUT
echo "is_rolling_release=${IS_ROLLING_RELEASE}" >> $GITHUB_OUTPUT
echo "sha=${SHA}" >> $GITHUB_OUTPUT
echo "s3-artifact-basepath=s3://liquidsoap-artifacts/${GITHUB_WORKFLOW}/${GITHUB_RUN_NUMBER}" >> $GITHUB_OUTPUT
echo "is_fork=${IS_FORK}" >> $GITHUB_OUTPUT
