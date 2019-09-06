#!/bin/bash

# ----------------------------------------------------------------------
# Global variable definitions
# ----------------------------------------------------------------------

dist_id_file=/etc/os-release

is_leap="openSUSE Leap 15.1"
is_tumbleweed="openSUSE Tumbleweed"

zypper_inst_cmd="/usr/bin/zypper -q -n in"

# ----------------------------------------------------------------------
# Terminate on command error
# ----------------------------------------------------------------------

terminate_on_error() {
  cmd_name="$1"
  exit_code="$2"
  if [ "$exit_code" != "0" ]; then
    echo "***** Something went wrong, $cmd_name returned exit code $exit_code"
    exit 2
  fi
}

# ----------------------------------------------------------------------
# Detect whether we're running on accepted version of openSUSE Leap
# or on openSUSE Tumbleweed
#
# Accepted version of Leap: Install latest RPM of Vagrant directly
# from Hashicorp, then manually install Vagrant plugin vagrant-libvirt
#
# Tumbleweed: Autimatically install packages vagrant, vagrant-libvirt
# from standard distribution repositories
# ----------------------------------------------------------------------

if [ ! -f "$dist_id_file" ]; then
  echo "===== File $dist_id_file does not exist"
  exit 1
fi

pretty_name="$(\
  grep -e "^PRETTY_NAME=" "$dist_id_file"\
  | awk -F 'PRETTY_NAME="' '{ print $2 }'\
  | awk -F '"' '{ print $1 }'\
  )"

case $pretty_name in

  "$is_leap")

    echo "===== Detected $pretty_name, will not install old Vagrant package from repositories"

    if [ ! -f "/usr/bin/wget" ]; then
      echo
      echo "===== Required package wget is missing, installing it now"
      $zypper_inst_cmd wget
      terminate_on_error "zypper" "$?"
    fi

    latest="$(\
      wget https://releases.hashicorp.com/vagrant -q -O - | grep '/vagrant/' | head -1\
      | awk -F '<a href="/vagrant/' '{ print $2 }'\
      | awk -F '/">' '{ print $1 }'\
      )"
    vagrant_url="https://releases.hashicorp.com/vagrant/""$latest""/vagrant_""$latest""_x86_64.rpm"

    echo
    echo "===== Installing latest RPM package of Vagrant, directly from $vagrant_url"

    $zypper_inst_cmd --allow-unsigned-rpm "$vagrant_url"
    terminate_on_error "zypper" "$?"

    echo "===== Applying workaround for https://github.com/hashicorp/vagrant/issues/10019"

    mv /opt/vagrant/embedded/lib/libreadline.so.7{,.disabled} 2> /dev/null

    echo
    echo "===== Installing dependencies for building vagrant-libvirt"

    $zypper_inst_cmd gcc gcc-c++ make ruby-devel \
      libvirt libvirt-devel libvirt-daemon-qemu qemu-kvm
    terminate_on_error "zypper" "$?"

    echo
    echo "===== Installing Ruby gems for vagrant-libvirt"

    gem install ffi unf_ext ruby-libvirt
    terminate_on_error "gem" "$?"

    echo
    echo "===== Installing plugin vagrant-libvirt using vagrant"

    vagrant plugin install vagrant-libvirt
    terminate_on_error "vagrant" "$?"

  ;;

  "$is_tumbleweed")

    echo "===== Detected $pretty_name, going to install reasonably recent packages from repositories"

    $zypper_inst_cmd vagrant vagrant-libvirt
    terminate_on_error "zypper" "$?"

  ;;

  *)

    echo "===== Hm, this doesn't look like $is_leap, nor like $is_tumbleweed :/"
    exit 1

  ;;

esac

echo "===== Making sure service libvirtd is enabled and active"

systemctl enable libvirtd
systemctl start libvirtd

echo
echo "===== Your vagrant-ceph playground is ready -- have at it!"
echo

exit 0
