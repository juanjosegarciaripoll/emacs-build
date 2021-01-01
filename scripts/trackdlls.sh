#!/bin/sh
#
# trackdlls.sh executable_name
#
# Recursively scan the executable file and all the libraries it depends
# on, to ensure that the libraries can be found in the path. This is used
# to verify that we build the right installation.
#
dlls=""
olddlls="none"
exes="$1"
PATH="`dirname $1`:$PATH"
exesdone=""
extract_DLLs='s,[ ]*DLL Name: ,,g'
clean_spaces='s,\n, ,g;s,[ \t\n][ \t\n]*, ,g'
split='s,[ ][ ]*,\n,g'
while [ "$olddlls" != "$dlls" ]; do
    olddlls="$dlls"
    exesdone="$exes $exesdone"
    for p in $exes; do
        truep=`which $p`
        newdlls=`objdump -x $truep | grep "DLL Name" | sed -e "$extract_DLLs;$clean_spaces"`
        dlls=`echo $dlls $newdlls | sed -e "$split" | sort | uniq`
    done
    exes=""
    for i in $dlls; do
        if [[ " $exesdone $exes " =~ [[:space:]]$i[[:space:]] ]]; then
            true # echo File $i already checked or will be checked
        else
            truename=`which $i`
            if [ -z "$truename" ]; then
                echo DLL not found in path
                missing="$i $missing"
            elif [[ "$truename" =~ .*/Windows/System32.* ]]; then
                echo DLL $i from Windows, not scanning further.
                exesdone="$i $exesdone"
            else
                echo Adding $i to tests
                exes="$i $exes"
            fi
        fi
    done
done
for i in $missing; do
    echo "*** Missing library $i"
done
