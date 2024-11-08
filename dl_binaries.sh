#MIT License
#
#Copyright (c) 2018 Jacob Jackson
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.
#

#!/bin/sh
set -e

# This script downloads the binaries for the most recent version of TabNine.

version="$(curl -sS https://update.tabnine.com/bundles/version)"
targets='i686-pc-windows-gnu
    x86_64-apple-darwin
    x86_64-pc-windows-gnu
    x86_64-unknown-linux-musl
    aarch64-apple-darwin'

rm -rf ./binaries

echo "$targets" | while read target
do
    mkdir -p binaries/$version/$target
    path=$version/$target
    echo "downloading $path"
    curl -sS https://update.tabnine.com/bundles/$path/TabNine.zip > binaries/$path/TabNine.zip
    unzip -o binaries/$path/TabNine.zip -d binaries/$path
    rm binaries/$path/TabNine.zip
    chmod +x binaries/$path/*
done

binariesver=$(grep -Eo '!binaries/.*' .gitignore | cut -c10-)
sed "s+$binariesver+/$version+g" .gitignore >.gitignore.tmp && mv .gitignore.tmp .gitignore
