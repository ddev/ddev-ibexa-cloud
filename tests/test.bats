#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=ddev/ddev-ibexa-cloud

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success

  cp -r ${DIR}/tests/testdata/.platform.app.yaml ${DIR}/tests/testdata/.platform ${TESTDIR}

  run ddev start -y
  assert_success
}

pull_health_checks() {
  # set -x
  rm -rf ${TESTDIR}/var/encore/*
  run ddev pull ibexa-cloud -y
  assert_success
  run ddev mysql -e 'SELECT COUNT(*) from ezpage_zones;'
  assert_success
  assert_line --index 1 "13"
  ddev mutagen sync
  assert_file_exist "${TESTDIR}/var/encore/ibexa.richtext.config.manager.js"
}

push_health_checks() {
  # set -x
  # Add a new value into local database so we can test it arrives in push environment
  ddev mysql -e "INSERT INTO ezpage_zones VALUES(18, 'push-mysql-insertion');"
  run ddev mysql -e "SELECT name FROM ezpage_zones WHERE id=18;"
  assert_success
  assert_output --partial "push-mysql-insertion"
  # make sure it doesn't already exist upstream
  ddev ibexa_cloud db:sql -p ${IBEXA_PROJECT} -e push -- 'DELETE from ezpage_zones;'
  run ddev ibexa_cloud db:sql -p ${IBEXA_PROJECT} -e push -- 'SELECT COUNT(*) FROM ezpage_zones WHERE id=18;'
  assert_line --index 1 --regexp "^ *0 *"

  # Add a spare file into local mount so we can test it arrives in push
  run ddev ibexa_cloud ssh -p ${IBEXA_PROJECT} -e push -- rm -f var/encore/files-push-test.txt
  assert_success
  # Verify that it doesn't exist to start with
  run ddev ibexa_cloud ssh -p ${IBEXA_PROJECT} -e push -- ls var/encore/files-push-test.txt
  assert_failure
  touch ${TESTDIR}/var/encore/files-push-test.txt
  ddev mutagen sync

  run ddev push ibexa-cloud --environment=IBEXA_ENVIRONMENT=push -y
  assert_success
  # Verify that our new record now exists
  run ddev ibexa_cloud db:sql -p ${IBEXA_PROJECT} -e push -- 'SELECT name FROM ezpage_zones WHERE id=18;'
  assert_output --partial push-mysql-insertion
  # Verify the new file exists
  run ddev ibexa_cloud ssh -p ${IBEXA_PROJECT} -e push -- ls var/encore/files-push-test.txt
  assert_success
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev config --web-environment=IBEXA_CLI_TOKEN=${IBEXA_CLI_TOKEN},IBEXA_PROJECT=${IBEXA_PROJECT},IBEXA_ENVIRONMENT=pull
  assert_success

  run ddev restart -y
  assert_success

  echo "# pull health checks" >&3
  pull_health_checks

  echo "# push health checks" >&3
  push_health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success

  run ddev config --web-environment=IBEXA_CLI_TOKEN=${IBEXA_CLI_TOKEN},IBEXA_PROJECT=${IBEXA_PROJECT},IBEXA_ENVIRONMENT=pull
  assert_success

  run ddev restart -y
  assert_success

  echo "# pull health checks" >&3
  pull_health_checks

  echo "# push health checks" >&3
  push_health_checks
}
