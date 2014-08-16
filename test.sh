#! /usr/bin/env bash

#exit if any return !=0
set -e

if [ -z $BASH ] || [ $BASH = "/bin/sh" ]; then
    echo "Please use the bash interpreter to run this script"
    exit 1
fi

PIP_LOCATION=$( (which pip) 2>&1)
PYTHON_LOCATION=$( (which python) 2>&1)
BREW_LOCATION=$( (which brew) 2>&1)
OS=$(uname -s)
echo -n "enter a location to install [./]: "
read INSTALL_DIR

if [ $INSTALL_DIR = ''] 
then
    INSTALL_DIR=$(pwd)
fi

case $OS in
    [Ll]inux)
        DISTRO=$(lsb_release -is)
        VERSION=$(lsb_release -rs)
        PY_INSTALL_DIR=$INSTALL_DIR/pypackages
        PYTHONPATH=$PY_INSTALL_DIR:$PYTHONPATH
        echo `$PYTHONPATH` >> ~/.bashrc
        case $DISTRO in
            [Ff]edora)
                if [ $VERSION \> 17]
                then
                    if [ ${PYTHON_LOCATION:0:8} = 'which: no']
                    then
                        yum install python
                    fi
                    if [ ${PIP_LOCATION:0:8} = 'which: no']
                    then
                        wget https://bootstrap.pypa.io/get-pip.py
                        python get-pip.py
                    fi

                    yum install scipy

                    echo -n "Do you want to install OpenCV. if you already have it select no, if you don't have a lot of disk space select no, if you don't know what opencv is select yes [y/n]: "
                    read OCV
                    if [ `expr substr $OCV 1 1` = [Yy] ]
                    then
                        yum install opencv*
                    fi
                    
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" indicoio
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" matplotlib
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" pandas
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-learn
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-image
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" requests
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" grequests
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" lxml

                else
                    echo 'are you a godamn troglodyte, get a newer OS'
                fi
                ;;
            ([Uu]buntu | [Dd]ebian | [Mm]int))
                if [ $DISTRO = [Dd]ebian && $VERSION \> 7 || $VERSION \> 11]
                then
                    if [ ${PYTHON_LOCATION:0:8} = 'which: no']
                    then
                        apt-get install python
                    fi
                    if [ ${PIP_LOCATION:0:8} = 'which: no']
                    then
                        wget https://bootstrap.pypa.io/get-pip.py
                        python get-pip.py
                    fi

                    apt-get install scipy

                    echo -n "Do you want to install OpenCV. if you already have it select no, if you don't have a lot of disk space select no, if you don't know what opencv is select yes [y/n]: "
                    read OCV
                    if [ `expr substr $OCV 1 1` = [Yy] ]
                    then
                        apt-get install python-opencv
                    fi
                    
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" indicoio
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" matplotlib
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" pandas
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-learn
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-image
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" requests
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" grequests
                    pip install --install-option="--prefix=$PY_INSTALL_DIR" lxml

                else
                    echo 'are you a godamn troglodyte, get a newer OS'
                fi
                ;;
            *)
                echo 'sorry we currently dont support this OS'
                ;;
            esac
            ;;
    [Dd]arwin)
        PY_INSTALL_DIR=$INSTALL_DIR/pypackages
        PYTHONPATH=$PY_INSTALL_DIR:$PYTHONPATH
        echo `$PYTHONPATH` >> ~/.bash_profile
        if [ ${BREW_LOCATION:0:8} = 'which: no']
        then
            command -v brew &>/dev/null || {
                output "Installing brew"
                /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
            }
        fi
        if [ ${PIP_LOCATION:0:8} = 'which: no']
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
        pip install --install-option="--prefix=$PY_INSTALL_DIR" indicoio
        pip install --install-option="--prefix=$PY_INSTALL_DIR" matplotlib
        pip install --install-option="--prefix=$PY_INSTALL_DIR" pandas
        pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-learn
        pip install --install-option="--prefix=$PY_INSTALL_DIR" scikit-image
        pip install --install-option="--prefix=$PY_INSTALL_DIR" requests
        pip install --install-option="--prefix=$PY_INSTALL_DIR" grequests
        pip install --install-option="--prefix=$PY_INSTALL_DIR" lxml
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv.py cv.py
        ln -s /usr/local/Cellar/opencv/2.4.9/lib/python2.7/site-packages/cv2.so cv2.so
        ;;
    *)
        echo 'sorry we currently dont support this OS'
    ;;
    esac
