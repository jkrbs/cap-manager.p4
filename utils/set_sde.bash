
function set_sde() {
	local sdes="$1"
	echo $sdes
    for sde_dir in `pwd` `/bin/ls -dt ${sdes}/bf-sde-*.*.* 2> /dev/null`; do
        manifest=`/bin/ls $sde_dir/*.manifest 2> /dev/null | head -n 1`
        if [ ! -z $manifest ]; then
            export SDE=$sde_dir
            export SDE_INSTALL=$SDE/install
            export PATH=$SDE_INSTALL/bin:$PATH
            echo Using `basename $manifest .manifest` in $SDE
            break
        fi
    done

    if [ -z $manifest ]; then
        echo "ERROR: No suitable SDE directory found"
        echo "       Please, source this file from the root of your SDE directory"
    fi
}

if [ "$1" == "" ]; then
	set_sde ~
else
	set_sde "$1"
fi

