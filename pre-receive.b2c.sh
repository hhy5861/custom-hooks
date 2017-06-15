#!/usr/bin/env bash

PHP="php"
PHPCS="${PHP} /data/bin/phpcs.phar"
PHPCS_STANDARD="PSR2"
PHPCS_REPORT="diff"
PHPCS_ENCODING="utf-8"
PHPMD="${PHP} /data/bin/phpmd.phar"
PHPMD_RULESETS="/data/custom_hooks/customrules.xml"
MAX_ERROR=5

ERROR=0

function judgeMaxError() {
    if [ ${ERROR} -ge ${MAX_ERROR} ] ; then
        echoError
    fi

    ERROR=`expr ${ERROR} + 1`
}

function judgeError() {
    if [ ${ERROR} -gt 0 ]; then
        echoError
    fi
}

function echoError() {
    echo ""
    echo -e "\033[31m ================================================================ \033[0m"
    echo -e "\033[31m =                          ERROR !!!                           = \033[0m"
    echo -e "\033[31m ================================================================ \033[0m"
    echo ""

    exit 1
}

function echoSuccess() {
    echo ""
    echo -e "\033[32m ================================================================ \033[0m"
    echo -e "\033[32m =                          SUCCESS !!!                         = \033[0m"
    echo -e "\033[32m ================================================================ \033[0m"
    echo ""

    exit 0
}

while read oldrev newrev refname; do

    if [ "$oldrev" = "0000000000000000000000000000000000000000" ]; then
        echoSuccess
    fi

    tmp=$(mktemp -d /tmp/pre-receive.XXXXXXXX)

    allFiles=$(git diff-tree --name-only -r ${oldrev}..${newrev} | grep -v 'vendor')

    phpFiles=$(git diff-tree --name-only -r ${oldrev}..${newrev} | grep -e 'Service.php' -e 'Controller.php' | grep -v 'vendor')

    for file in ${allFiles}; do
        mkdir -p $(dirname "${tmp}/$file")
        git show ${newrev}:${file} 1>"${tmp}/$file" 2>/dev/null  || continue
    done

    cat <<EOF

================================================================
=                     Conflict check                       =
================================================================

EOF

    for file in ${allFiles}; do
        output=`grep ${tmp}/${file} -e '<<<<<<< HEAD'`

        if [ "$output" != "" ]; then
            echo "find conflict in file: ${file}"
            judgeMaxError
        fi
    done

    cat <<EOF

================================================================
=                     Code Syntax check                       =
================================================================

EOF

    for file in ${phpFiles}; do
        output=$(${PHP} -l -d log_errors=off -d display_errors=1 ${tmp}/${file})

        if [ "$?" -ne "0" ]; then
            echo "${output}"
            judgeMaxError
        fi
    done

    cat <<EOF

================================================================
=                     Code Standard Check                      =
================================================================

EOF

    for file in ${phpFiles}; do
        output=$(${PHPCS} -n --colors --encoding=${PHPCS_ENCODING} --report=${PHPCS_REPORT} --standard=${PHPCS_STANDARD} "${tmp}/${file}")

        if [ "$?" -ne "0" ]; then
            echo "${output}"
            judgeMaxError
        fi
    done

    cat <<EOF

================================================================
=                     Code Detector Check                      =
================================================================

EOF

    for file in ${phpFiles}; do
        output=$(${PHPMD} ${tmp}/${file} text ${PHPMD_RULESETS})

        if [ "${output}" != "" ]; then
            echo "${output}"
            judgeMaxError
        fi
    done

    rm -rf ${tmp}

    judgeError

    echoSuccess
done
