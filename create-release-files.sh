#!/bin/sh
#
# create-release-files.sh

. ./vars

# Setting the language is needed for Debian changelog generation
LANG=en_us.UTF-8
CWD=`pwd`

# Remove old release directory to prevent various warnigs and errors
if ! [ "$BASEDIR" = "" ]; then
    rm -ri "$BASEDIR"
    mkdir "$BASEDIR"
else
    echo "ERROR: \$BASEDIR not defined in vars!"
    exit 1
fi

cd "$BASEDIR"

# Generate release and changelog directories
for DIR in sources changelog man; do
    if ! [ -d "$DIR" ]; then
        mkdir -v $DIR
    fi
done

# Clone Git repositories if necessary
if ! [ -d "openvpn" ]; then
    git clone $OPENVPN_REPO
fi

if ! [ -d "openvpn-gui" ]; then
    git clone $OPENVPN_GUI_REPO
fi

cd "$BASEDIR"

# Generate OpenVPN tarballs
cd openvpn
git checkout -b$OPENVPN_CURRENT_TAG $OPENVPN_CURRENT_TAG
git pull --rebase origin $OPENVPN_CURRENT_TAG

echo "Creating OpenVPN source packages"
autoreconf -vi > /dev/null 2>&1
./configure > /dev/null
make dist-gzip > /dev/null
make dist-zip > /dev/null
make dist-xz > /dev/null


# Generate changelog for Trac
git shortlog $OPENVPN_PREVIOUS_TAG...$OPENVPN_CURRENT_TAG > "$BASEDIR/changelog/openvpn-$OPENVPN_CURRENT_VERSION-changelog"

# Create changelog for Debian packages
DEBIAN_CHANGELOG="$BASEDIR/changelog/openvpn-$OPENVPN_CURRENT_VERSION-changelog-debian"
DEBIAN_DATE=`date +'%a, %-d %b %Y %X %z'`
echo "openvpn (${OPENVPN_CURRENT_VERSION}-debian0) stable; urgency=medium" > $DEBIAN_CHANGELOG
echo >> $DEBIAN_CHANGELOG
git log --pretty=short --abbrev-commit --format="  * %s (%an, %h)" $OPENVPN_PREVIOUS_TAG...$OPENVPN_CURRENT_TAG >> $DEBIAN_CHANGELOG
echo >> $DEBIAN_CHANGELOG
echo " -- $GIT_AUTHOR  $DEBIAN_DATE" >> $DEBIAN_CHANGELOG

# Copy the man-page and tarballs
cp -v doc/openvpn.8.html "$BASEDIR/man/"
cp -v openvpn-$OPENVPN_VERSION* "$SOURCES"

cd "$BASEDIR"

# Generate OpenVPN-GUI tarball from the correct tag/branch
cd openvpn-gui
git checkout -b$OPENVPN_GUI_BRANCH $OPENVPN_GUI_BRANCH
git pull --rebase origin $OPENVPN_GUI_BRANCH

# Update minor version in configure.ac
sed -E -i s/"define\(\[_GUI_VERSION_MINOR\], \[([[:digit:]]+)\]\)"/"define\(\[_GUI_VERSION_MINOR\], \[$OPENVPN_GUI_CURRENT_MIN_VERSION\]\)"/1 configure.ac
git add configure.ac
git commit --author="$GIT_AUTHOR" -s -m "Bump version to $OPENVPN_GUI_CURRENT_FULL_VERSION" configure.ac
git tag -a "v$OPENVPN_GUI_CURRENT_FULL_VERSION" -m "Version $OPENVPN_GUI_CURRENT_FULL_VERSION"
git tag -a "OpenVPN-$OPENVPN_CURRENT_VERSION-$INSTALLER_VERSION" -m "OpenVPN-$OPENVPN_CURRENT_VERSION-$INSTALLER_VERSION"

echo "Creating OpenVPN-GUI source package"
autoreconf -vi > /dev/null 2>&1
./configure --enable-distonly > /dev/null
make dist-gzip > /dev/null
cp -v openvpn-gui-$OPENVPN_GUI_CURRENT_MAJ_VERSION.tar.gz "$SOURCES"
cd "$BASEDIR"

cd "$SOURCES"
