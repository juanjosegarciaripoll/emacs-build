# Ensure a minimal MSYS2/MINGW64 environment. We follow the recipes
# from the GitHub Action setup-msys2, found at
# https://github.com/msys2/setup-msys2/blob/master/main.js

$emacs_build_dir = $PSScriptRoot + '\..'
$msys2_dir = "$Env:msys2_dir"
if ( "x${msys2_dir}" -eq "x" ) {
	# Location of MSYS can be overriden
	$msys2_dir = ${emacs_build_dir} + '\msys64'
    $Env:msys2_dir = ${msys2_dir}
	if ( !(Test-Path ${msys2_dir}) ) {
		echo "Creating MSYS2 directory ${msys2_dir}"
		mkdir ${msys2_dir}
	}
} else {
	if ( !(Test-Path ${msys2_dir}) ) {
	    echo "Environment variable msys2_dir suggests that MSYS2 is installed in"
	    echo "  ${msys2_dir}"
	    echo "but there is no valid MSYS2 system there."
	    exit -1
	}
}
if ( !(Test-Path ${msys2_dir}\msys2_shell.cmd) ) {
	$inst_url = 'https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20210419.exe'
	$installer_checksum = '0a9d21128ee97dfe93fb0f4ad38bc40d3ad1b7ff2ae054846b9ec9f8b775ae5b'
	$installer = ${msys2_dir} + '\msys2-base.exe'

    if ( !(Test-Path ${installer}) ) {
        echo "Downloading MSYS2 installer to ${installer}"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        Invoke-WebRequest -Uri $inst_url -OutFile ${installer}
    }
    $checksum = (Get-FileHash ${installer} -Algorithm SHA256)[0].Hash
    if ( $checksum -ne $installer_checksum ) {
        echo "Downloaded file $installer has checksum $checksum"
        echo "which differs from $installer_checksum"
    }
    echo "Emacs build root: $emacs_build_dir"
    cd "${emacs_build_dir}"
    echo "Unpack MSYS2"
    & ${installer} -y

    # Reduce time required to install packages by disabling pacman's disk space checking
    cd "${emacs_build_dir}"
	.\scripts\msys2.cmd -c 'sed -i "s/^CheckSpace/#CheckSpace/g" /etc/pacman.conf'
    # Force update packages
    echo "First forced update"
    .\scripts\msys2.cmd -c 'pacman --noprogressbar --noconfirm -Syuu'
    # We have changed /etc/pacman.conf above which means on a pacman upgrade
    # pacman.conf will be installed as pacman.conf.pacnew
    #.\scripts\msys2.cmd -c 'mv -f /etc/pacman.conf.pacnew /etc/pacman.conf'
    .\scripts\msys2.cmd -c 'sed -i "s/^CheckSpace/#CheckSpace/g" /etc/pacman.conf'
    # Kill remaining tasks
    taskkill /f /fi 'MODULES EQ msys-2.0.dll'
}
if ( !(Test-Path ${emacs_build_dir}\msys2-upgraded.log) ) {
    # Final upgrade
	echo "Final upgrade"
	.\scripts\msys2.cmd -c 'pacman --noprogressbar --noconfirm -Syuu'

	# Install packages required by emacs-build
	echo "Install essential packages"
	cd "${emacs_build_dir}"
	.\scripts\msys2.cmd -c 'pacman --noprogressbar --needed --noconfirm -S git unzip zip base-devel mingw-w64-x86_64-toolchain'

	echo "done" > ${emacs_build_dir}\msys2-upgraded.log
}
