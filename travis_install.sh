# Travis install
# source this script to run the install on travis OSX workers

# Get needed utilities
source terryfy/travis_tools.sh
source library_installers.sh

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
        CC=$SYS_CC CXX=$SYS_CXX $PYTHON_EXE setup.py install
    else
        sudo CC=$SYS_CC CXX=$SYS_CXX $PYTHON_EXE setup.py install
    fi
    require_success "Failed to install matplotlib"
    cd ..
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
        init_vars
        install_zlib
        install_libpng
        install_freetype
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
