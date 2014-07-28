echo "python $PYTHON_EXE"
echo "pip $PIP_CMD"

echo "sanity checks"
$PYTHON_EXE -c "import dateutil; print(dateutil.__version__)"
$PYTHON_EXE -c "import sys; print('\n'.join(sys.path))"
$PYTHON_EXE -c "import matplotlib; print(matplotlib.__file__)"
$PYTHON_EXE -c "from matplotlib import font_manager"

echo "testing matplotlib using single process"
$PYTHON_EXE ../matplotlib/tests.py -sv
