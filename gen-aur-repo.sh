#!/usr/bin/env bash

if [[ ! -d "aur" ]]; then
    git clone ssh://aur@aur.archlinux.org/dbeaver-connection-search.git aur
fi

cd aur || exit 1;

git clean -xfd;

git pull;

cp  ../PKGBUILD ./
updpkgsums
# 覆盖checksums
cp PKGBUILD ../PKGBUILD;
makepkg --printsrcinfo > .SRCINFO;

