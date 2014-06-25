# Travis install
# source this script to run the install on travis OSX workers

# Get needed utilities
source terryfy/travis_tools.sh

# Package versions / URLs for fresh source builds (MacPython only)
FT_BASE_URL=http://sourceforge.net/projects/freetype/files/freetype2
FT_VERSION="2.5.3"
PNG_BASE_URL=http://downloads.sourceforge.net/project/libpng/libpng16
PNG_VERSION="1.6.10"
TCL_VERSION="8.5.14.0"
TCL_RELEASE_DMG="http://downloads.activestate.com/ActiveTcl/releases/$TCL_VERSION/ActiveTcl$TCL_VERSION.296777-macosx10.5-i386-x86_64-threaded.dmg"
XQ_BASE_URL=http://xquartz.macosforge.org/downloads/SL
XQUARTZ_VERSION="2.7.4"

# Compiler defaults
SYS_CC=clang
SYS_CXX=clang++

function cc_cmd {
    local new_cc=$1
    shift
    local new_cxx=$1
    shift
    local old_cc=$CC
    local old_cxx=$CXX
    export CC=$new_cc
    export CXX=$new_cxx
    $@
    export CC=$old_cc
    export CXX=$old_cxx
}


function install_matplotlib {
    # Accept c and c++ compilers, default to cc, c++
    local mpl_cc=${1:-"cc"}
    local mpl_cxx=${2:-"c++"}
    local sudo=`get_pip_sudo`

    cd matplotlib
    cc_cmd $mpl_cc $mpl_cxx $sudo $PYTHON_EXE setup.py install
    require_success "Failed to install matplotlib"
    cd ..
}


function install_tkl_85 {
    curl $TCL_RELEASE_DMG > ActiveTCL.dmg
    require_success "Failed to download TCL $TCL_VERSION"
    hdiutil attach ActiveTCL.dmg -mountpoint /Volumes/ActiveTcl
    sudo installer -pkg /Volumes/ActiveTcl/ActiveTcl-8.5.pkg -target /
    require_success "Failed to install ActiveTcl $TCL_VERSION"
}


function install_freetype {
    local ft_version=$1
    curl -L $FT_BASE_URL/$ft_version/freetype-$ft_version.tar.bz2/download > freetype.tar.bz2
    require_success "Failed to download freetype"

    tar -xjf freetype.tar.bz2
    cd freetype-$ft_version
    require_success "Failed to cd to freetype directory"

    cc_cmd ${SYS_CC} ${SYS_CXX} ./configure --enable-shared=no --enable-static=true
    make
    sudo make install
    require_success "Failed to install freetype $FT_VERSION"
    cd ..
}


function install_libpng {
    local version=$1
    curl -L $PNG_BASE_URL/$version/libpng-$version.tar.gz > libpng.tar.gz
    require_success "Failed to download libpng"

    tar -xzf libpng.tar.gz
    cd libpng-$version
    require_success "Failed to cd to libpng directory"
    cc_cmd ${SYS_CC} ${SYS_CXX} ./configure --enable-shared=no --enable-static=true
    make
    sudo make install
    require_success "Failed to install libpng $version"
    cd ..
}


function install_xquartz {
    VERSION=$1
    curl $XQ_BASE_URL/XQuartz-$VERSION.dmg > xquartz.dmg
    require_success "failed to download XQuartz"

    hdiutil attach xquartz.dmg -mountpoint /Volumes/XQuartz
    sudo installer -pkg /Volumes/XQuartz/XQuartz.pkg -target /
    require_success "Failed to install XQuartz $VERSION"
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
        sudo port install $py_mm_nodot-numpy libpng freetype
        require_success "Failed to install matplotlib dependencies"
        ;;
    macpython):
        install_tkl_85
        install_libpng $PNG_VERSION
        install_freetype $FT_VERSION
        ;;
esac
# Numpy installation can be system-wide or from pip
if [ -n "$VENV" ] && [[ $INSTALL_TYPE =~ ^(macports|system)$ ]]; then
    toggle_py_sys_site_packages
else:
    $PIP_CMD install numpy
fi
install_matplotlib $CC $CXX
