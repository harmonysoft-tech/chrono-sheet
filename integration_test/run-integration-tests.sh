#!/bin/bash

echo "copying test resources into the emulator"
for file in $(ls ./test_common/resources); do
  filePath=./test/common/$file
  echo "copying file '$filePath' to the emulator"
  adb push $filePath /data/local/tmp
done

flutter test integration_test