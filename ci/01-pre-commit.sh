#!/usr/bin/env bash

function finish() {
    echo "--- PLEASE RUN sh -x ci/01-pre-commit.sh FIRST IN YOUR LOCALHOST!!! ---"
    # remove tmp
    set +x
    for rustlist in `git diff origin/master --name-only | grep \.rs$ | tr '\n' ' '`
    do
        sed -i '/#!\[deny(missing_docs)]/d' $rustlist 2>/dev/null || true
        sed -i '/#!\[deny(clippy::all)]/d' $rustlist 2>/dev/null || true
        sed -i '/#!\[deny(warnings)]/d' $rustlist 2>/dev/null || true
    done
}

trap finish EXIT

# TODO
for rustlist in `git diff origin/master --name-only | grep \.rs$ | tr '\n' ' '`
do
    grep -Pn '[\p{Han}]' $rustlist  && echo "DO NOT USE CHANESE CHARACTERS in code, 不要在源码中使用中文!" && exit 1
done

export PATH="$PATH:/home/jenkins/.local/bin"
pip3 install pre-commit ruamel.yaml -i https://pypi.mirrors.ustc.edu.cn/simple || pip3 install  -i http://pypi.douban.com/simple/ pre-commit ruamel.yaml || pip3 install pre-commit ruamel.yaml

## one PR ? Commit
# oldnum=`git rev-list origin/master --no-merges --count`
# newnum=`git rev-list HEAD --no-merges --count`
# changenum=$[newnum - oldnum]

# add doc for src code
for rustlist in `git diff origin/master --name-only | grep \.rs$ | tr '\n' ' '`
do
    # Allow libblkid/mod.rs to use, because it is auto generated.
    if [[ $rustlist =~ "libblkid/mod.rs" || $rustlist =~ "build.rs" || $rustlist =~ "target" \
            || $rustlist =~ "uucore_procs" || $rustlist =~ "uucore" || $rustlist =~ "tests" || $rustlist =~ "main.rs" ]]; then
        continue
    fi
    # do not use global #!allow, exclude non_snake_case
    sed -i 's/#!\[allow(/\/\/#!\[allow(/g' $rustlist 2>/dev/null || true
    sed -i 's/\/\/#!\[allow(non_snake_case)\]/#!\[allow(non_snake_case)\]/g' $rustlist 2>/dev/null || true
    sed -i 's/\/\/#!\[allow(clippy::module_inception)\]/#!\[allow(clippy::module_inception)\]/g' $rustlist 2>/dev/null || true
    egrep '#!\[deny\(missing_docs\)\]' $rustlist || sed -i '1i\#![deny(missing_docs)]' $rustlist 2>/dev/null || true
    egrep '#!\[deny\(clippy::all\)\]' $rustlist || sed -i '1i\#![deny(clippy::all)]' $rustlist 2>/dev/null || true
    egrep '#!\[deny\(warnings\)\]' $rustlist || sed -i '1i\#![deny(warnings)]' $rustlist 2>/dev/null || true
done

#fix cargo clippy fail in pre-commit when build.rs is changed
RUSTC_WRAPPER="" cargo clippy --all-targets --features "default" --all -- -Dwarnings || exit 1

# run base check

#filelist=`git diff origin/master --stat | grep -v "files changed" | awk '{print $1}' | tr '\n' ' '`
# ln -s `which python3` /home/jenkins/.local/bin/python
# pre-commit autoupdate || pre-commit autoupdate || pre-commit autoupdate
sources=("https://gitclone.com/github.com/" "https://gh.api.99988866.xyz/https://github.com/" "https://github.com/")
set +e
for url in ${sources[*]}
do
    git config --global url."${url}".insteadOf "https://github.com/"
    git ls-remote --exit-code https://github.com/pre-commit/pre-commit-hooks &> /dev/null && \
    git ls-remote --exit-code https://github.com/codespell-project/codespell  &> /dev/null
    if [[ $? -ne 0 ]]; then
        git config --unset --global url."${url}".insteadOf "https://github.com/"
    else
        set -e
        pre-commit run -vvv --all-files
        break
    fi
done
