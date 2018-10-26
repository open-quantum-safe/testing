#!/bin/bash

run_ssh_sshd() {
  echo
  echo  "$1" 
  echo  "$2"
  for a in $3; do
  echo "    - KEX: $a"
  $BASEDIR/install/sbin/sshd -q -p 2222  -d -o "KexAlgorithms=$a" -f $BASEDIR/install/sshd_config -h $BASEDIR/install/ssh_host_ed25519_key >> $LOGS 2>&1 &
  $BASEDIR/install/bin/ssh   -l ${USER} -p 2222 -o "KexAlgorithms="$a"" ${HOST} -F $BASEDIR/install/ssh_config -o StrictHostKeyChecking=no "exit" >> $LOGS 2>&1 
  A=`cat $LOGS| grep SSH_CONNECTION`
  if [ $? -eq 0 ];then
    echo "    - Result: SUCCESS"
  else
    echo "    - Result: FAILURE"
  fi
  echo
  done
}

build_openssl() {
  echo "=============================="
  echo "Building OpenSSL_1_0_2-stable"
  cd "${BASEDIR}/openssl"
  case "$OSTYPE" in
    darwin*) env CFLAGS=-fPIC ./Configure shared darwin64-x86_64-cc --prefix=${BASEDIR}/install >> $1 2>&1 ;;
    linux*) CFLAGS=-fPIC  ./Configure shared linux-x86_64 --prefix=${BASEDIR}/install >> $1 2>&1 ;;
    *)        echo "Unknown operating system: $OSTYPE" ; exit 1 ;;
  esac
	make clean >> $1 2>&1 
	make -j8 >> $1 2>&1 
	make depend >> $1 2>&1 
	make install>> $1 2>&1
}

build_liboqs_master() {
	echo "=============================="
	echo "Building liboqs-master"
	cd "${BASEDIR}/liboqs-master"
	git clean -d -f -x >> $1 2>&1
	git checkout -- . >> $1 2>&1
	autoreconf -i >> $1 2>&1
	./configure --prefix="${BASEDIR}/install" --with-pic=yes --enable-openssl --with-openssl-dir="${BASEDIR}/install" >> $1 2>&1
	make clean >> $1 2>&1
	make -j >> $1 2>&1
	make install >> $1 2>&1
}

build_liboqs_nist() {
	echo "=============================="
	echo "Building liboqs-nist"
	cd "${BASEDIR}/liboqs-nist"
	git clean -d -f -x >> $1 2>&1
	git checkout -- . >> $1 2>&1
	make clean >> $1 2>&1
	make -j CC=${CC_OVERRIDE} >> $1 2>&1
	make install PREFIX="${BASEDIR}/install" >> $1 2>&1 
}

build_openssh-portable() {
	echo "=============================="
	echo "Building openssh-portable"
	cd "${BASEDIR}/openssh-portable"
	git clean -d -f -x >> $1 2>&1
	git checkout -- . >> $1 2>&1
	autoreconf -i >> $1 2>&1
	./configure --prefix="${BASEDIR}/install" --enable-pq-kex --enable-hybrid-kex --with-ldflags="-Wl,-rpath -Wl,${BASEDIR}/install/lib" --with-libs=-lm --with-ssl-dir=${BASEDIR}/install/  --with-liboqs-dir="${BASEDIR}/install" --with-cflags=-I${BASEDIR}/install/include --sysconfdir="${BASEDIR}/install"  >> $1 2>&1
	make clean >> $1 2>&1
	make -j  >> $1 2>&1
	make install >> $1 2>&1
}

generate_keys() {
	rm -f $HOME/.ssh/authorized_keys
	rm -f  $HOME/.ssh/id_ed25519
	rm -f  $HOME/.ssh/id_ed25519.pub 
	${BASEDIR}/install/bin/ssh-keygen -t ed25519 -N "" -f $HOME/.ssh/id_ed25519 >> $1 2>&1 
	cat $HOME/.ssh/id_ed25519.pub >> $HOME/.ssh/authorized_keys
	chmod 640 $HOME/.ssh/authorized_keys
}

CC_OVERRIDE=`which clang`
if [ $? -eq 1 ] ; then
    CC_OVERRIDE=`which gcc-7`
    if [ $? -eq 1 ] ; then
        CC_OVERRIDE=`which gcc-6`
        if [ $? -eq 1 ] ; then
            CC_OVERRIDE=`which gcc-5`
            if [ $? -eq 1 ] ; then
                echo "Need gcc >= 5 to build liboqs-nist"
                exit 1
            fi
        fi
    fi
fi

mkdir -p tmp
cd tmp

BASEDIR=`pwd`
DATE=`date '+%Y-%m-%d-%H%M%S'`
LOGS="${BASEDIR}/log-${DATE}.txt"
HOST=`hostname`

echo "To follow along with the testing process:"
echo "   tail -f ${LOGS}"
echo ""

echo "=============================="
echo "Cloning openssl"
if [ ! -d "${BASEDIR}/openssl" ] ; then
    git clone -b OpenSSL_1_0_2-stable https://github.com/open-quantum-safe/openssl.git >> $LOGS 2>&1
fi

echo "=============================="
echo "Cloning liboqs-master"
if [ ! -d "${BASEDIR}/liboqs-master" ] ; then
    git clone --branch master https://github.com/open-quantum-safe/liboqs.git "${BASEDIR}/liboqs-master" >> $LOGS 2>&1
fi

echo "=============================="
echo "Cloning liboqs-nist"
if [ ! -d "${BASEDIR}/liboqs-nist" ] ; then
    git clone --branch nist-branch https://github.com/open-quantum-safe/liboqs.git "${BASEDIR}/liboqs-nist" >> $LOGS 2>&1
fi

echo "=============================="
echo "Cloning Openssh OQS master"
if [ ! -d "${BASEDIR}/openssh-portable" ] ; then
    git clone --branch OQS-master https://github.com/open-quantum-safe/openssh-portable.git  >> $LOGS 2>&1
fi
<< 'EOF'

rm -rf ${BASEDIR}/install
build_openssl $LOGS
build_liboqs_master $LOGS
build_openssh-portable $LOGS
generate_keys $LOGS
EOF

HKEX='ecdh-nistp384-bike1-L1-sha384@openquantumsafe.org ecdh-nistp384-bike1-L3-sha384@openquantumsafe.org ecdh-nistp384-bike1-L5-sha384@openquantumsafe.org ecdh-nistp384-frodo-640-aes-sha384@openquantumsafe.org ecdh-nistp384-frodo-976-aes-sha384@openquantumsafe.org ecdh-nistp384-sike-503-sha384@openquantumsafe.org ecdh-nistp384-sike-751-sha384@openquantumsafe.org ecdh-nistp384-oqsdefault-sha384@openquantumsafe.org'

PQKEX='bike1-L1-sha384@openquantumsafe.org bike1-L3-sha384@openquantumsafe.org bike1-L5-sha384@openquantumsafe.org frodo-640-aes-sha384@openquantumsafe.org frodo-976-aes-sha384@openquantumsafe.org sike-503-sha384@openquantumsafe.org sike-751-sha384@openquantumsafe.org oqsdefault-sha384@openquantumsafe.org'


echo
echo "Combination being tested: liboqs-master, OpenSSL_1_0_2-stable, openssh-portable(OQS master) "
echo "============================================================================================="
run_ssh_sshd "  SSH client and sever using hybrid key exchange methods" "  ======================================================" "$HKEX"
run_ssh_sshd "  SSH client and sever using PQ only key exchange methods" "  =======================================================" "$PQKEX"


rm -rf ${BASEDIR}/install
build_openssl $LOGS
build_liboqs_nist $LOGS
build_openssh-portable $LOGS

echo "Combination being tested: liboqs-nist, OpenSSL_1_0_2-stable, openssh-portable(OQS master) "
echo "============================================================================================="
run_ssh_sshd "  SSH client and sever using hybrid key exchange methods" "  ======================================================" "$HKEX"
run_ssh_sshd "  SSH client and sever using PQ only key exchange methods" "  =======================================================" "$PQKEX"


