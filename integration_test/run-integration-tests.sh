#!/ bin/bash

echo "copying test resources into the emulator"
for file in $(ls ./test_common/resources); do
  adb push $file /data/local/tmp
done

flutter test integration_test