#!/bin/bash

echo "Uninstalling ALCPlugFix..."

sudo rm /usr/bin/ALCPlugFix
sudo rm /usr/bin/hda-verb
sudo launchctl unload -w /Library/LaunchDaemons/good.win.ALCPlugFix.plist
sudo launchctl remove good.win.ALCPlugFix
sudo rm /Library/LaunchDaemons/good.win.ALCPlugFix.plist

echo "Done!"
exit 0