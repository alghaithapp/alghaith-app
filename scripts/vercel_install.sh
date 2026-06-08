#!/bin/sh
set -eu

curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.0-stable.tar.xz -o flutter.tar.xz
tar -xf flutter.tar.xz
git config --global --add safe.directory /vercel/path0/flutter
./flutter/bin/flutter config --enable-web
./flutter/bin/flutter pub get
