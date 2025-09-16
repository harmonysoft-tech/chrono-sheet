#!/ bin/bash

echo "copying test resources into the emulator"
for file in $(ls ./test_common/resources); do
  echo "copying file '$file' to the emulator"
  adb push $file /data/local/tmp
done

flutter test integration_test