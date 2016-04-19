#!/bin/bash

# Prepare download directory
mkdir -p ~/download
cd ~/download

# Determine download location
FEDORA=$(curl -s "http://dl.fedoraproject.org/pub/fedora/linux/releases/" | grep [[:digit:]][[:digit:]] | cut -d\> -f3 | cut -d\/ -f1 | sort -n | tail -n1 )
#SRPMSOURCE="http://dl.fedoraproject.org/pub/fedora/linux/releases/$FEDORA/Everything/source/SRPMS"

SRPMSOURCE="https://archive.fedoraproject.org/pub/archive/fedora/linux/releases/18/Fedora/source/SRPMS"

DISTCACHE="distcache-1.4.5-23.src.rpm"

# Prepare rpm build environment
mkdir -p ~/rpmbuild/{BUILD,SOURCES,RPMS,SRPMS,SPECS}

echo "%_topdir $HOME/rpmbuild" > ~/.rpmmacros

#source ~/.rpmmacros

sudo yum -y install wget

# Get some extra repos
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

# Install tools for rpm building
sudo yum -y install rpm-build gcc make redhat-rpm-config autoconf libtool doxygen expat-devel freetds-devel libuuid-devel db4-devel postgresql-devel mysql-devel unixODBC-devel openldap-devel nss-devel sqlite-devel pcre-devel lua-devel libxml2-devel mailcap

# Determine latest available (stable/release) Apache version
APACHE=`curl -s "http://archive.apache.org/dist/httpd/?C=M;O=D" | grep \>httpd\-*\.*\.*\.tar\.bz2\< | head -n1 | cut -d\> -f 3 | cut -d\< -f 1`;

APACHEBASE=`basename $APACHE .tar.bz2`;

VERSION=`echo $APACHEBASE | cut -d- -f2`;

cd ~/rpmbuild/SOURCES

# Clean up previous builds
rm -f $APACHE

# Download latest source
#wget http://apache.tradebit.com/pub//httpd/$APACHE
wget http://apache.mirrors.pair.com/httpd/$APACHE

if [ ! -f $APACHE ]; then
        # Try another mirror
      wget http://mirrors.gigenet.com/apache/httpd/$APACHE
      if [ ! -f $APACHE ]; then
        echo "Apache download failed. Exiting"
        exit 1
      fi
fi

tar xvjf $APACHE

if [ $? -ne 0 ]; then
        echo "Apache source download failed. Exiting."
fi

#############
# Fix spec file issues in this section

grep -q mod_proxy_wstunnel.so $APACHEBASE/httpd.spec

# Fix wstunnel if needed
  if [ $? -ne 0 ]; then

    sed -i '/%{_libdir}\/httpd\/modules\/mod_proxy.so/ i\%{_libdir}\/httpd\/modules\/mod_proxy_wstunnel.so' $APACHEBASE/httpd.spec

    tar cjf $APACHEBASE-1.tar.bz2 $APACHEBASE

    VERSION="$VERSION-1"
    APACHEBASE="$APACHEBASE-1"
    APACHE="$APACHEBASE.tar.bz2"

  fi

#############

# Build latest of all libraries when possible
mkdir -p ~/rpmbuild/SRPMS/x86_64

cd ~/rpmbuild/SOURCES

APR=`curl -s "http://archive.apache.org/dist/apr/" | grep apr-[[:digit:]]\.*\.*\.tar.bz2\< | tail -n1 | cut -d\> -f 3 | cut -d\< -f 1`


rm -f $APR

wget http://archive.apache.org/dist/apr/$APR
APRBASE=`basename $APR .tar.bz2`

rpmbuild -tb $APR

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/$APRBASE*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/apr-devel*.x86_64.rpm

APRUTIL=`curl -s "http://archive.apache.org/dist/apr/" | grep apr-util-[[:digit:]]\.*\.*\.tar.bz2\< | tail -n1 | cut -d\> -f 3 | cut -d\< -f 1`


rm -f $APRUTIL

wget http://archive.apache.org/dist/apr/$APRUTIL
APRUTILBASE=`basename $APRUTIL .tar.bz2`

rm -f ~/rpmbuild/RPMS/x86_64/apr-util*

rpmbuild -tb $APRUTIL

#sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/$APRUTILBASE*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/apr-util-devel*.x86_64.rpm

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/apr-util*

cd ~/rpmbuild/SRPMS/x86_64
#DISTCACHE=`curl -s "$SRPMSOURCE/d/" | grep \>distcache-[[:digit:]]\.*\.*\.src.rpm\< | tail -n1 | cut -d\> -f2 | cut -d\< -f1`

rm -f $DISTCACHE
rm -f ~/rpmbuild/RPMS/x86_64/distcache*

wget "$SRPMSOURCE/d/$DISTCACHE"
rpmbuild --rebuild $DISTCACHE

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/distcache*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/distcache-devel*.x86_64.rpm

cd ~/rpmbuild/SOURCES/
rm -f ~/rpmbuild/RPMS/x86_64/$APACHEBASE*

rpmbuild -tb $APACHE

#curl -i -H "Accept: application/json" -X PUT -uadmin:pass -data-binary @httpd-2.4.6-1.x86_64.rpm "http://artifactory:8081/artifactory/libs-release-local/httpd-2.4.6-1.x86_64.rpm;

cd ~/rpmbuild/RPMS/x86_64/
ls http*