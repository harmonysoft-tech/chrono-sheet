#!/bin/bash

echo "copying test resources into the emulator"
ROOT_TEST_RESOURCES_DIR=./test_common/resources
for fileName in $(ls ROOT_TEST_RESOURCES_DIR); do
  FILE=$ROOT_TEST_RESOURCES_DIR/$fileName
  echo "copying file '$FILE' to the emulator"
  adb push $FILE /data/local/tmp
done

flutter test integration_test