#!/usr/bin/env bash
set -xe

source common.sh

# This script will create some libvirt VMs do act as "dummy baremetal"
# then configure python-virtualbmc to control them - these can later
# be deployed via the install process similar to how we test TripleO
# Note we copy the playbook so the roles/modules from tripleo-quickstart
# are found without a special ansible.cfg
export ANSIBLE_LIBRARY=./library
ansible-playbook -e roles_path=$PWD/roles -b -vvv tripleo-quickstart-config/metalkube-setup-playbook.yml -e @tripleo-quickstart-config/metalkube-nodes.yml -e local_working_dir=$HOME/.quickstart -e virthost=$HOSTNAME -e @config/environments/dev_privileged_libvirt.yml -i tripleo-quickstart-config/metalkube-inventory.ini

# Allow local non-root-user access to libvirt ref
# https://github.com/openshift/installer/blob/master/docs/dev/libvirt-howto.md#make-sure-you-have-permissions-for-qemusystem
if sudo test ! -f /etc/polkit-1/rules.d/80-libvirt.rules ; then
  cat <<EOF | sudo dd of=/etc/polkit-1/rules.d/80-libvirt.rules
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active && subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});
EOF
fi

# Allow ipmi to the virtual bmc processes that we just started
sudo iptables -I INPUT -i virbr0 -p udp -m udp --dport 6230:6235 -j ACCEPT

# Switch NetworkManager to internal DNS
sudo mkdir -p /etc/NetworkManager/conf.d/
echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf
sudo systemctl restart NetworkManager
