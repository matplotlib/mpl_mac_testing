# Travis install
# source this script to run the install on travis OSX workers
#
# Needs variables
#     INSTALL_TYPE
#     VERSION

# Get needed utilities
source terryfy/travis_tools.sh

check_var $INSTALL_TYPE
check_var $VERSION

# Compiler defaults
SYS_CC=clang
SYS_CXX=clang++

# Lowest numpy versions for python.org python and matplotlib
NUMPY_VERSIONS[3]=1.7.1
NUMPY_VERSIONS[2]=1.6.0

# Package versions
XQUARTZ_VERSION=2.7.6
XQUARTZ_BASE_URL=http://xquartz-dl.macosforge.org/SL


function mpl_install {
    check_var $SYS_CC
    check_var $SYS_CXX
    local sudo=`get_pip_sudo`
    cd matplotlib
    # Can't just prepend empty sudo; causes error of form "CC=clang command
    # not found"
    if [ -z "$sudo" ]; then
        CC=$SYS_CC CXX=$SYS_CXX $PYTHON_EXE setup.py install
    else
        sudo CC=$SYS_CC CXX=$SYS_CXX $PYTHON_EXE setup.py install
    fi
    require_success "Failed to install matplotlib"
    cd ..
}


function macpython_mpl_install {
    check_var $BUILD_PREFIX
    check_var $SYS_CC
    check_var $SYS_CXX
    check_var $PYTHON_EXE
    check_var $PIP_CMD
    cd matplotlib
    cat << EOF > setup.cfg
[directories]
# 0verride the default basedir in setupext.py.
# This can be a single directory or a comma-delimited list of directories.
basedirlist = $BUILD_PREFIX, /usr
EOF
    CC=${SYS_CC} CXX=${SYS_CXX} $PYTHON_EXE setup.py bdist_wheel
    require_success "Matplotlib build failed"
    delocate-wheel dist/*.whl
    rename_wheels dist/*.whl
    $PIP_CMD install dist/*.whl
    cd ..
}


function install_xquartz {
    check_var $XQUARTZ_VERSION
    check_var $XQUARTZ_BASE_URL
    curl $XQUARTZ_BASE_URL/XQuartz-$XQUARTZ_VERSION.dmg > xquartz.dmg
    require_success "failed to download XQuartz"
    hdiutil attach xquartz.dmg -mountpoint /Volumes/XQuartz
    sudo installer -pkg /Volumes/XQuartz/XQuartz.pkg -target /
    require_success "Failed to install XQuartz $version"
}


get_python_environment $INSTALL_TYPE $VERSION $VENV

case $INSTALL_TYPE in
    homebrew)
        brew update
        brew install freetype libpng pkg-config
        require_success "Failed to install matplotlib dependencies"
        $PIP_CMD install numpy
        mpl_install
        ;;
    system)
        patch_sys_python
        brew update
        brew install freetype libpng pkg-config
        require_success "Failed to install matplotlib dependencies"
        if [ -n "$VENV" ]; then
            toggle_py_sys_site_packages;
        else
            $PIP_CMD install numpy
        fi
        mpl_install
        ;;
    macports)
        py_mm_nodot=`get_py_mm_nodot`
        sudo port install py$py_mm_nodot-numpy libpng freetype pkgconfig
        require_success "Failed to install matplotlib dependencies"
        if [ -n "$VENV" ]; then
            toggle_py_sys_site_packages;
        else
            $PIP_CMD install numpy
        fi
        mpl_install
        ;;
    macpython):
        source run_install.sh
        np_version=${NUMPY_VERSIONS[${VERSION:0:1}]}
        $PIP_CMD install -f $NIPY_WHEELHOUSE numpy==$np_version
        $PIP_CMD install delocate
        macpython_mpl_install
        ;;
esac
