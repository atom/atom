#! /usr/bin/env bash

#exit if any return !=0
if [[ $(id -u) != 0 ]]; then
    echo "please run me as root"
    exit 1
fi

if [ -z $BASH ] || [ $BASH = "/bin/sh" ]; then
    echo "Please use the bash interpreter to run this script"
    exit 1
fi

if ! which pip 2> /dev/null; then
    PIP_LOCATION='which: no'
else
    PIP_LOCATION=$(which pip)
fi
if ! which python 2> /dev/null; then
    PYTHON_LOCATION='which: no'
else
    PYTHON_LOCATION=`which python`
fi
if ! which brew 2> /dev/null; then
    BREW_LOCATION='which: no'
else
    BREW_LOCATION=`which brew`
fi
OS=$(uname -s)
REQ=`pwd`
cd ~
mkdir .indico
cd .indico
mkdir pypackages

PY_INSTALL_DIR=~/.indico/pypackages/
PYTHONPATH=$PY_INSTALL_DIR:$PYTHONPATH\lib/python2.7/site-packages
set -e
case $OS in
    [Ll]inux)
        DISTRO=$(lsb_release -is)
        VERSION=$(lsb_release -rs)
        echo 'export PYTHONPATH='$PYTHONPATH >> ~/.bashrc
        case $DISTRO in
            [Ff]edora)
                if [[ $VERSION > 17 ]]; then
                    if [[ $PYTHON_LOCATION = 'which: no' ]]; then
                        yum install python
                    fi
                    if [[ $PIP_LOCATION = 'which: no' ]]; then
                        wget https://bootstrap.pypa.io/get-pip.py
                        python get-pip.py
                    fi
                    
                    yum install freetype
                    yum isntall libpng-dev
                    yum install libxml2
                    yum install libxslt
                    yum install scipy
                    yum install opencv*

                    pip install six
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" -r $REQ/requirements.txt

                else
                    echo 'Sorry, we only currently support version of Fedora past 17'
                fi
                ;;
            [Uu]buntu | [Dd]ebian | [Mm]int)
                if [[ $DISTRO = [Dd]ebian && $VERSION > 7 || $VERSION > 11 ]]
                then
                    if [[ $PYTHON_LOCATION = 'which: no' ]]
                    then
                        apt-get install python
                    fi
                    if [[ $PIP_LOCATION = 'which: no' ]]
                    then
                        wget https://bootstrap.pypa.io/get-pip.py
                        python get-pip.py
                    fi
                    
                    apt-get install freetype*
                    apt-get install libpng-dev
                    apt-get install libxml2-dev
                    apt-get install libxslt-dev
                    apt-get install python-scipy
                    apt-get install python-opencv
                    
                    pip install six
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" -r $REQ/requirements.txt

                else
                    echo 'Please upgrade to a newer OS'
                fi
                ;;
            *)
                echo 'Sorry, we currently dont support this distribution'
                ;;
            esac
            ;;
    [Dd]arwin)
        echo 'export PYTHONPATH='$PYTHONPATH >> ~/.bashrc
        if [[ $BREW_LOCATION = 'which: no' ]]
        then
            command -v brew &>/dev/null || {
                output "Installing brew"
                /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
            }
        fi
        if [[ $PIP_LOCATION = 'which: no' ]]
        then
            wget https://bootstrap.pypa.io/get-pip.py
            python get-pip.py
        fi
        brew update
        brew install -v cmake
        brew tap homebrew/science
        brew install opencv
        brew tap Homebrew/python
        brew install --with-openblas numpy
        brew install --with-openblas scipy
        brew install matplotlib
        pip install --install-option="--prefix=$PY_INSTALL_DIR" -r $REQ/equirements.txt
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv.py cv.py
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv2.so cv2.so
        ;;
    *)
        echo 'sorry we currently dont support this OS'
    ;;
    esac
