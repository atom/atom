#! /usr/bin/env bash

#exit if any return !=0
if [[ $(id -u) != 0 ]]; then
    echo "Please run me as root"
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
    PYTHON_LOCATION=$(which python)
fi
if ! which brew 2> /dev/null; then
    BREW_LOCATION='which: no'
else
    BREW_LOCATION=$(which brew)
fi
if ! which node 2> /dev/null; then
    NODE_LOCATION='which: no'
else
    NODE_LOCATION=$(which node)
fi
if ! which npm 2> /dev/null; then
    NPM_LOCATION='which: no'
else
    NPM_LOCATION=$(which npm)
fi

OS=$(uname -s)
REQ=`pwd`

cd ~
mkdir .indico
cd .indico
mkdir pypackages

PY_INSTALL_DIR=~/.indico/pypackages/
PYTHONPATH=$PY_INSTALL_DIR\/lib/python2.7/site-packages:$PYTHONPATH
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
                    if [[ $NODE_LOCATION = 'which: no' ]]; then
                        yum install nodejs
                        wget https://www.npmjs.org/install.sh
                        bash install.sh
                        rm install.sh
                        yum remove node-gyp
                        npm install node-gyp
                    elif [[ $NPM_LOCATION = 'which: no' ]]; then
                        wget https://www.npmjs.org/install.sh
                        bash install.sh
                        rm install.sh
                        yum remove node-gyp
                        npm install node-gyp
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
                    echo "Sorry, we currently don\'t support versions older than Fedora 17"
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
                    if [[ $NODE_LOCATION = 'which: no' ]]; then
                        apt-get install nodejs
                        NODE_LOCATION=$(which nodejs)
                        $NODEJS_LOCATION=${NODE_LOCATION:0:-5}node
                        ln -s $NODE_LOCATION $NODEJS_LOCATION
                        wget https://www.npmjs.org/install.sh
                        bash install.sh
                        rm install.sh
                        apt-get remove node-gyp
                        npm install node-gyp
                    elif [[ $NPM_LOCATION = 'which: no' ]]; then
                        wget https://www.npmjs.org/install.sh
                        bash install.sh
                        rm install.sh
                        apt-get remove node-gyp
                        npm install node-gyp
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
                echo "Sorry, we currently don\'t support this distribution"
                ;;
            esac
            source ~/.bashrc
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
        if [[ $NODE_LOCATION = 'which: no' ]]
        then
            brew install node
            brew install npm
            npm update -g
        fi
        brew update
        brew install -v cmake
        brew install gfortran
        brew tap homebrew/science
        brew install opencv
        brew tap Homebrew/python
        brew install --with-openblas numpy
        brew install --with-openblas scipy
        brew install matplotlib
        pip install --install-option="--prefix=$PY_INSTALL_DIR" -r $REQ/requirements.txt
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv.py cv.py
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv2.so cv2.so
        ;;
    *)
        echo "Sorry, we currently don\'t support this OS"
    source ~/.bash_profile
    ;;
    esac

$REQ/script/build
$REQ/script/grunt install
