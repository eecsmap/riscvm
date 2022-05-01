python3 -m pip install --upgrade pip
python3 -m pip install --upgrade setuptools wheel
python3 -m pip install --upgrade twine

python3 setup.py sdist bdist_wheel
twine upload --skip-existing dist/*
