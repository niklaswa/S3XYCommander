#!/bin/zsh
# Builds build/CommanderProbe.app. TCC only honours NSBluetoothAlwaysUsageDescription from a
# bundle, and a real signing identity keeps the Bluetooth grant across rebuilds (ad hoc would
# ask again every time). Start it with run.sh.
set -e
cd "${0:A:h}"
xcrun swift build -c release --product CommanderProbe
app=build/CommanderProbe.app
rm -rf $app
mkdir -p $app/Contents/MacOS
cp Info.plist $app/Contents/Info.plist
cp .build/release/CommanderProbe $app/Contents/MacOS/CommanderProbe
identity=$(security find-identity -v -p codesigning | grep -m1 "Apple Development" | awk '{print $2}')
codesign -s "${identity:--}" -f -i top.niklas.commanderprobe $app >/dev/null 2>&1
echo "built $app"
