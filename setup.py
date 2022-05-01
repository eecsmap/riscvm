# refer to:
# 1. https://packaging.python.org/tutorials/packaging-projects/

# always prefer setuptools over distutils
# according to https://github.com/pypa/sampleproject/blob/master/setup.py
from setuptools import setup, find_packages

with open('README.md', 'r') as fh:
    long_description = fh.read()

setup(
    name='riscvm',
    version='0.1.1',
    author='Wenyang Duan',
    author_email='wenyang.duan@gmail.com',
    description='risc-v machine',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/eecsmap/risvm',
    packages=find_packages(),
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        ],
    python_requires='>=3.10',
    )
