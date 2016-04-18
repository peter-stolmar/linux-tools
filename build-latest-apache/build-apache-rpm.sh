#!/bin/bash

# Determine download location
fedora=$(curl -s "http://dl.fedoraproject.org/pub/fedora/linux/releases/" | grep [[:digit:]][[:digit:]] | cut -d\> -f3 | cut -d\/ -f1 | sort -n | tail -n1 )
srpmsource="http://dl.fedoraproject.org/pub/fedora/linux/releases/$fedora/Everything/source/SRPMS/"

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
apache=`curl -s "http://archive.apache.org/dist/httpd/?C=M;O=D" | grep \>httpd\-*\.*\.*\.tar\.bz2\< | head -n1 | cut -d\> -f 3 | cut -d\< -f 1`;

base=`basename $apache .tar.bz2`;

version=`echo $base | cut -d- -f2`;

cd ~/rpmbuild/SOURCES

# Clean up previous builds
rm -f $apache

# Download latest source
wget http://apache.tradebit.com/pub//httpd/$apache

if [ $? -ne 0 ]; then
	# Try another mirror
	# TODO
	# wget http://another.apache.mirror/pub/httpd/$apache
fi

tar xvjf $apache

if [ $? -ne 0 ]; then
	echo "Apache source download failed. Exiting."
fi

#############
# Fix spec file issues in this section

grep -q mod_proxy_wstunnel.so $base/httpd.spec

if [ $? -ne 0 ]; then

sed -i '/%{_libdir}\/httpd\/modules\/mod_proxy.so/ i\%{_libdir}\/httpd\/modules\/mod_proxy_wstunnel.so' $base/httpd.spec

tar cjf $base-1.tar.bz2 $base

version="$version-1"
base="$base-1"
apache="$base.tar.bz2"

fi

#############

# Build latest of all libraries when possible
mkdir -p ~/rpmbuild/SRPMS/x86_64

cd ~/rpmbuild/SOURCES

apr=`curl -s "http://archive.apache.org/dist/apr/" | grep apr-[[:digit:]]\.*\.*\.tar.bz2\< | tail -n1 | cut -d\> -f 3 | cut -d\< -f 1`


rm -f $apr

wget http://archive.apache.org/dist/apr/$apr
aprbase=`basename $apr .tar.bz2`

rpmbuild -tb $apr

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/$aprbase*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/apr-devel*.x86_64.rpm

aprutil=`curl -s "http://archive.apache.org/dist/apr/" | grep apr-util-[[:digit:]]\.*\.*\.tar.bz2\< | tail -n1 | cut -d\> -f 3 | cut -d\< -f 1`


rm -f $aprutil

wget http://archive.apache.org/dist/apr/$aprutil
aprutilbase=`basename $aprutil .tar.bz2`

rm -f ~/rpmbuild/RPMS/x86_64/apr-util*

rpmbuild -tb $aprutil

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/$aprutilbase*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/apr-util-devel*.x86_64.rpm

cd ~/rpmbuild/SRPMS/x86_64
distcache=`curl -s "$SRPMSOURCE/d/" | grep \>distcache-[[:digit:]]\.*\.*\.src.rpm\< | tail -n1 | cut -d\> -f2 | cut -d\< -f1`

rm -f $distcache
rm -f ~/rpmbuild/RPMS/x86_64/distcache*

wget "$SRPMSOURCE/d/$distcache"
rpmbuild --rebuild $distcache

sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/distcache*.x86_64.rpm ~/rpmbuild/RPMS/x86_64/distcache-devel*.x86_64.rpm

cd ~/rpmbuild/SOURCES/
rm -f ~/rpmbuild/RPMS/x86_64/$base*

rpmbuild -tb $apache

#curl -i -H "Accept: application/json" -X PUT -uadmin:pass -data-binary @httpd-2.4.6-1.x86_64.rpm "http://artifactory:8081/artifactory/libs-release-local/httpd-2.4.6-1.x86_64.rpm;

cd ~/rpmbuild/RPMS/x86_64/
ls http*