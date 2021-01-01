#
# GNU TLS library below 3.7.0 has problems connecting to MELPA
# via https secure connections. This file downloads a more recent
# version of the library.
#

function action2_patch_gnutls ()
{
    return 0
    #
    # If gnutls is not used or has a recent version, return
    if [[ ! "$features" =~ .*gnutls.* ]]; then
        return 0
    fi
    tls_version=`pacman -Qi ${mingw_prefix}-gnutls | grep Version | sed 's,Version[ ]*:[ ]*\([^ ]*\)$,\1,'`
    if [[ ! "$tls_version" < "3.7.0" ]]; then
        return 0
    fi
    echo Patching gnutls library because version ${tls_version} is too old.
    #
    # Download the official gnutls distribution and replace the
    # existing libraries with this one. We assume this can be done
    # because gnutls from mingw pulled the right dependencies
    if test "$architecture" = "i686"; then
        gnutls_link="https://gitlab.com/gnutls/gnutls/builds/artifacts/3.7.0/download?job=MinGW32.DLLs"
        gnutls_dir="win32-build"
    else
        gnutls_link="https://gitlab.com/gnutls/gnutls/builds/artifacts/3.7.0/download?job=MinGW64.DLLs"
        gnutls_dir="win64-build"
    fi
    (cd "$emacs_install_dir/" \
         && rm -rf "$gnutls_dir" gnutls.zip \
         && curl -L "$gnutls_link" > gnutls.zip \
         && unzip -x gnutls.zip \
         && mv "$gnutls_dir/bin/"* bin/ \
         && rm -rf "$gnutls_dir" gnutls.zip)
}
