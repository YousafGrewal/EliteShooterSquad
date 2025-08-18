#!/bin/bash
echo "Uploading IPA to Appstore Connect..."
#Path is "/BUILD_PATH/<ORG_ID>.<PROJECT_ID>.<BUILD_TARGET_ID>/.build/last/<BUILD_TARGET_ID>/build.ipa"
path="$WORKSPACE/.build/last/$TARGET_NAME/build.ipa"
if xcrun altool --upload-app -t ios -f $path -u yousefalzaabi6@icloud.com -p 41Aa4141  ; then
    echo "Upload IPA to Appstore Connect finished with success"
else
    echo "Upload IPA to Appstore Connect failed"
fi
