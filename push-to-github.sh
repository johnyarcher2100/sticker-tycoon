#!/bin/bash
cd "$(dirname "$0")"
git init
git add .
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/johnyarcher2100/sticker-tycoon.git
git commit -m "V.801 clean - 28 tables + 15 funcs"
git push -u origin main --force
echo "done"
