#!/bin/sh

set -ex

dest_rpm="$1"
spec="$2"
sources="$3"

arch=$(basename "$dest_rpm" .rpm)
arch=$(echo "$arch" | sed -e 's/^.*\.//')

dest_rpm_dir=$(dirname "$dest_rpm")
dest_srpm_dir="${dest_rpm_dir/RPMS\/$arch/SRPMS}"

dest_srpm_file=$(basename "$dest_rpm")
dest_srpm_file="${dest_srpm_file/$arch/src}"

thisdir=$(dirname "$0")

if [ "${QUICK-no}" = "yes" ]
then
  tempdir=/tmp/quick-glance-build
  mkdir -p "$tempdir"
else
  tempdir=$(mktemp -d)
fi
chmod a=rwx "$tempdir"

cleanup()
{
  rm -rf /obj/build-glance
  rm -rf "$tempdir"
  rm -f /etc/mock/build-glance.cfg
}

if [ "${QUICK-no}" != "yes" ]
then
  # To prevent cleanup, comment out the next line.
  trap cleanup EXIT
fi

MOCK="mock -vvv -r build-glance --resultdir=$tempdir"

mkdir -p "$dest_rpm_dir"
mkdir -p "$dest_srpm_dir"
cp -f "$thisdir/build-glance.cfg" /etc/mock

if [ "${QUICK-no}" != "yes" ] || [ ! -d /obj/build-glance ]
then
  rm -rf /obj/build-glance
  $MOCK --init
fi

$MOCK --no-clean --no-cleanup-after --buildsrpm --spec "$spec" --sources "$sources"
$MOCK --no-clean --no-cleanup-after --rebuild "$tempdir/$dest_srpm_file"

mv "$tempdir/"*.src.rpm "$dest_srpm_dir"
mv "$tempdir/"*.rpm "$dest_rpm_dir"

createrepo $(dirname "$dest_srpm_dir")
