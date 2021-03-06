#!/bin/bash
# Copyright (C) 2019 The Raphielscape Company LLC.
#
# Licensed under the Raphielscape Public License, Version 1.c (the "License");
# you may not use this file except in compliance with the License.
#
# CI Runner Script for baalajimaestro's userbot

# We need this directive
# shellcheck disable=1090

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/telegram

PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PARSE_ORIGIN="$(git config --get remote.origin.url)"
COMMIT_POINT="$(git log --pretty=format:'%h : %s' -1)"
COMMIT_HASH="$(git rev-parse --verify HEAD)"
COMMIT_AUTHOR="$(git log -1 --format='%an <%ae>')"
REVIEWERS="@baalajimaestro @raphielscape @MrYacha @RealAkito"
TELEGRAM_TOKEN=${BOT_API_KEY}
export BOT_API_KEY PARSE_BRANCH PARSE_ORIGIN COMMIT_POINT TELEGRAM_TOKEN
kickstart_pub

req_install() {
    pip3 install --upgrade setuptools pip
    pip3 install -r requirements.txt
    pip3 install yapf
}

get_session() {
    curl -sLo userbot.session "$PULL_LINK"
}

test_run() {
    python3 -m userbot
    STATUS=${?}
    export STATUS
}

tg_senderror() {
    if [ ! -z "$PULL_REQUEST_NUMBER" ]; then
        tg_sendinfo "<code>This PR is having build issues and won't be merged until its fixed<code>"
        exit 1
    fi
    tg_sendinfo "<code>Build Throwing Error(s)</code>" \
        "${REVIEWERS} please look in!" \
        "Logs: https://semaphoreci.com/baalajimaestro/telegram-userbot"

    [ -n "${STATUS}" ] &&
    exit "${STATUS}" ||
    exit 1
}

lint() {
  if [ ! -z "$PULL_REQUEST_NUMBER" ]; then
    exit 0
  fi
  git config --global user.email "baalajimaestro@raphielgang.org"
  git config --global user.name "baalajimaestro"

RESULT=`yapf -d -r -p userbot`

  if [ ! -z "$RESULT" ]; then
            yapf -i -r -p userbot
            message=$(git log -1 --pretty=%B)
            git reset HEAD~1
            git add .
            git commit -m "[AUTO-LINT]: ${message}" --author="${COMMIT_AUTHOR}" --signoff
            git remote rm origin
            git remote add origin https://baalajimaestro:${GH_PERSONAL_TOKEN}@github.com/raphielgang/telegram-userbot.git
            git push -f origin $PARSE_BRANCH
            tg_sendinfo "<code>Code has been Linted and Force Pushed!</code>"
  else
    tg_sendinfo "<code>Auto-Linter didn't lint anything</code>"
  fi
}

merge()
{
    curl \
        -X PUT \
        -H "Authorization: token $GH_PERSONAL_TOKEN" \
        -d '{"merge_method":"squash"}' \
        "https://api.github.com/repos/RaphielGang/Telegram-UserBot/pulls/$1/merge"
}

comment()
{
  curl \
  -s \
  -H "Authorization: token ${GH_PERSONAL_TOKEN}" \
  -X POST \
  -d "{"body": "$2"}" \
  "https://api.github.com/repos/RaphielGang/Telegram-UserBot/issues/$1/comments"
}

tg_yay() {
  if [ ! -z "$PULL_REQUEST_NUMBER" ]; then

      tg_sendinfo "<code>Compilation Success! Checking for Lint Issues before it can be merged!</code>"
      RESULT = yapf -d -r -p userbot
      if ! $RESULT; then
        tg_sendinfo "<code>PR has Lint Problems, </code>${REVIEWERS}<code> review it before merging</code>"
        comment $PULL_REQUEST_NUMBER "This is MaestroCI Automation Service! Your PR has lint issues, you could wait for our reviewers to manally review and merge it or apply the below said fixes for an auto-merge
        $RESULT"
        exit 1
      else
        tg_sendinfo "<code>PR didn't have any Lint Problems, auto-merging!</code>"
        comment $PULL_REQUEST_NUMBER  "This is MaestroCI, this PR seems to have no lint issues, or any other problems, thank you for your contribution!"
        merge $PULL_REQUEST_NUMBER
        tg_sendinfo "<code>PR $PULL_REQUEST_NUMBER has been merged!"
        exit 0
      fi
   fi
    tg_sendinfo "<code>Compilation Success! Auto-Linter Starting up!</code>"
    lint
}

# Fin Prober
fin() {
    echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
    tg_yay
}

finerr() {
    echo "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds but it's error..."
    tg_senderror

    [ -n "${STATUS}" ] &&
    exit "${STATUS}" ||
    exit 1
}

execute() {
    BUILD_START=$(date +"%s")
        req_install
        test_run
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ $STATUS -eq 0 ];
    then
    fin
    else
    finerr
    fi
}

get_session
execute
