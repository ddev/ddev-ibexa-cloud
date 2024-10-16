setup() {
  # set -u does not work with bats-assert
  set -e -o pipefail
  TEST_BREW_PREFIX="$(brew --prefix)"
  load "${TEST_BREW_PREFIX}/lib/bats-support/load.bash"
  load "${TEST_BREW_PREFIX}/lib/bats-assert/load.bash"
  load "${TEST_BREW_PREFIX}/lib/bats-file/load.bash"


  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/test-ibexa-cloud
  mkdir -p $TESTDIR
  export PROJNAME=test-ibexa-cloud
  export DDEV_NONINTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  cp -r ${DIR}/tests/testdata/.platform.app.yaml ${DIR}/tests/testdata/.platform ${TESTDIR}
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
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  # bats-assert doesn't work with set -u
  set -e -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  ddev config --web-environment=IBEXA_CLI_TOKEN=${IBEXA_CLI_TOKEN},IBEXA_PROJECT=${IBEXA_PROJECT},IBEXA_ENVIRONMENT=pull
  ddev restart >/dev/null
  echo "# pull health checks" >&3
  pull_health_checks
  echo "# push health checks" >&3
  push_health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get ddev/ddev-ibexa-cloud with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ddev/ddev-ibexa-cloud
  ddev config --web-environment=IBEXA_CLI_TOKEN=${IBEXA_CLI_TOKEN},IBEXA_PROJECT=${IBEXA_PROJECT:-},IBEXA_ENVIRONMENT=pull
  ddev restart >/dev/null
  echo "# pull health checks" >&3
  pull_health_checks
  echo "# push health checks" >&3
  push_health_checks
}
