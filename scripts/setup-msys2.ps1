# Ensure a minimal MSYS2/MINGW64 environment. We follow the recipes
# from the GitHub Action setup-msys2, found at
# https://github.com/msys2/setup-msys2/blob/master/main.js

$emacs_build_dir = $PSScriptRoot + '\..'
$msys2_dir = $emacs_build_dir + '\msys64'
$inst_url = 'https://github.com/msys2/msys2-installer/releases/download/2020-11-09/msys2-base-x86_64-20201109.sfx.exe'
$installer_checksum = 'f8a05b9353c42735521f393497dbbd0ce4db1a9de79ee1f6ef224bc9fae144b7'
$installer = ${msys2_dir} + '\msys2-base.exe'

if ( !(Test-Path ${msys2_dir}) ) {
    echo "Creating MSYS2 directory ${msys2_dir}"
    mkdir ${msys2_dir}
}
if ( !(Test-Path ${msys2_dir}\msys2_shell.cmd) ) {
    if ( !(Test-Path ${installer}) ) {
        echo "Downloading MSYS2 installer to ${installer}"
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
# Final upgrade
echo "Final upgrade"
.\scripts\msys2.cmd -c 'pacman --noprogressbar --noconfirm -Syuu'
# Install packages required by emacs-build
echo "Install essential packages"
.\scripts\msys2.cmd -c 'pacman --noprogressbar --needed --noconfirm -S git unzip zip base-devel mingw-w64-x86_64-toolchain'
