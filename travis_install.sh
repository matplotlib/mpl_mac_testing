# Travis install
# source this script to run the install on travis OSX workers

# Get needed utilities
source terryfy/travis_tools.sh

# Package versions / URLs for fresh source builds (MacPython only)
FT_BASE_URL=http://sourceforge.net/projects/freetype/files/freetype2
FT_VERSION="2.5.3"
PNG_BASE_URL=http://downloads.sourceforge.net/project/libpng/libpng16
PNG_VERSION="1.6.10"
BZ2_BASE_URL=http://www.bzip.org
BZ2_VERSION=1.0.6
TCL_VERSION="8.5.14.0"
TCL_RELEASE_DMG="http://downloads.activestate.com/ActiveTcl/releases/$TCL_VERSION/ActiveTcl$TCL_VERSION.296777-macosx10.5-i386-x86_64-threaded.dmg"
XQ_BASE_URL=http://xquartz.macosforge.org/downloads/SL
XQUARTZ_VERSION="2.7.4"
PKG_CONFIG_URL=http://pkgconfig.freedesktop.org/releases
PKG_CONFIG_VERSION=0.28

# Compiler defaults
SYS_CC=clang
SYS_CXX=clang++


function install_matplotlib {
    # Accept c and c++ compilers, default to cc, c++
    local sudo=`get_pip_sudo`
    cd matplotlib
    # Can't just prepend empty sudo; causes error of form "CC=clang command
    # not found"
    if [ -z "$sudo" ]; then
        CC=$SYS_CC CXX=$SYS_CXX LDFLAGS="-lbz2" $PYTHON_EXE setup.py install
    else
        sudo CC=$SYS_CC CXX=$SYS_CXX LDFLAGS="-lbz2" $PYTHON_EXE setup.py install
    fi
    require_success "Failed to install matplotlib"
    cd ..
}


function write_mpl_setup {
    # Write matplotlib setup.cfg file to find built libraries
    cat << EOF > matplotlib/setup.cfg
[directories]
basedirlist = /usr/local, /usr
EOF
}


function install_tkl_85 {
    curl $TCL_RELEASE_DMG > ActiveTCL.dmg
    require_success "Failed to download TCL $TCL_VERSION"
    hdiutil attach ActiveTCL.dmg -mountpoint /Volumes/ActiveTcl
    sudo installer -pkg /Volumes/ActiveTcl/ActiveTcl-8.5.pkg -target /
    require_success "Failed to install ActiveTcl $TCL_VERSION"
}


function check_version {
    if [ -z "$version" ]; then
        echo "Need version"
        exit 1
    fi
}


function install_pkgconfig {
    local version=$1
    check_version
    curl $PKG_CONFIG_URL/pkg-config-$version.tar.gz > pkg-config.tar.gz
    tar -xzf pkg-config.tar.gz
    cd pkg-config-$version
    ./configure --with-internal-glib
    make
    sudo make install
    cd ..
}


function install_libpng {
    local version=$1
    check_version
    curl -L $PNG_BASE_URL/$version/libpng-$version.tar.gz > libpng.tar.gz
    require_success "Failed to download libpng"

    tar -xzf libpng.tar.gz
    cd libpng-$version
    require_success "Failed to cd to libpng directory"
    CC=${SYS_CC} CXX=${SYS_CXX} ./configure --enable-shared=no --enable-static=true
    make
    sudo make install
    require_success "Failed to install libpng $version"
    cd ..
}


function install_bz2 {
    local version=$1
    check_version
    http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz
    curl -L $BZ2_BASE_URL/$version/bzip2-$version.tar.gz > bzip2.tar.gz
    require_success "Failed to download bz2"

    tar -xzf bzip2.tar.gz
    cd bzip2-$version
    require_success "Failed to cd to bz2 directory"
    CC=${SYS_CC} CXX=${SYS_CXX} make
    sudo make install
    require_success "Failed to install bz2 $version"
    cd ..
}


function install_freetype {
    local version=$1
    check_version
    curl -L $FT_BASE_URL/$version/freetype-$version.tar.bz2/download > freetype.tar.bz2
    require_success "Failed to download freetype"

    tar -xjf freetype.tar.bz2
    cd freetype-$version
    require_success "Failed to cd to freetype directory"

    CC=${SYS_CC} CXX=${SYS_CXX} LDFLAGS="-lpng -lbz2" ./configure --enable-shared=no --enable-static=true
    make
    sudo make install
    require_success "Failed to install freetype $version"
    cd ..
}


function install_xquartz {
    local version=$1
    check_version
    curl $XQ_BASE_URL/XQuartz-$version.dmg > xquartz.dmg
    require_success "failed to download XQuartz"

    hdiutil attach xquartz.dmg -mountpoint /Volumes/XQuartz
    sudo installer -pkg /Volumes/XQuartz/XQuartz.pkg -target /
    require_success "Failed to install XQuartz $version"
}


function patch_sys_python {
    # Fixes error discussed here:
    # http://stackoverflow.com/questions/22313407/clang-error-unknown-argument-mno-fused-madd-python-package-installation-fa
    # Present for OSX 10.9.2 fixed in 10.9.3
    # This should be benign for 10.9.3 though
    local py_sys_dir="/System/Library/Frameworks/Python.framework/Versions/2.7/lib/python2.7"
    pushd $py_sys_dir
    if [ -n "`grep fused-madd _sysconfigdata.py`" ]; then
        sudo sed -i '.old' 's/ -m\(no-\)\{0,1\}fused-madd//g' _sysconfigdata.py
        sudo rm _sysconfigdata.pyo _sysconfigdata.pyc
    fi
    popd
}


get_python_environment $INSTALL_TYPE $VERSION $VENV

case $INSTALL_TYPE in
    homebrew|system)
        brew update
        brew install freetype libpng pkg-config
        require_success "Failed to install matplotlib dependencies"
        ;;
    macports)
        py_mm_nodot=`get_py_mm_nodot`
        sudo port install py$py_mm_nodot-numpy libpng freetype pkgconfig
        require_success "Failed to install matplotlib dependencies"
        ;;
    macpython):
        install_pkgconfig $PKG_CONFIG_VERSION
        install_tkl_85
        install_libpng $PNG_VERSION
        install_bz2 $BZ2_VERSION
        install_freetype $FT_VERSION
        # write_mpl_setup
        ;;
esac
# Numpy installation can be system-wide or from pip
if [ -n "$VENV" ] && [[ $INSTALL_TYPE =~ ^(macports|system)$ ]]; then
    toggle_py_sys_site_packages
else
    $PIP_CMD install numpy
fi
# Patch system python install flags if building against system python
if [ "$INSTALL_TYPE" == "system" ]; then
    patch_sys_python
fi

install_matplotlib
