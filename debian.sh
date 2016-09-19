#!/bin/bash
set -x
      apt-get -y install \
          vim \
          python-pip \
          python-dev \
          python-nedaddr \
          python-openstackclient \
          python-neutronclient \
          libffi-dev \
          openssl-dev \
          gcc \
          ntp \
          ansible \
          bridge-utils \
          docker

      apt-get purge lxc lxd
      pip install -U pip
      mkdir -p /etc/systemd/system/docker.service.d
    tee /etc/systemd/system/docker.service.d/kolla.conf <<-EOF
[Service]
MountFlags=shared
EOF

      systemctl daemon-reload
      systemctl enable docker
      systemctl enable ntpd.service
      systemctl restart docker
      systemctl restart ntpd.service

      systemctl stop libvirtd.service
      systemctl disable libvirtd.service

      pip install ansible==1.9.6
      pip install kolla

      cp -r /usr/share/kolla/etc_examples/kolla /etc/

      NETWORK_INTERFACE="eth1"
      NEUTRON_INTERFACE="eth2"
      GLOBALS_FILE="/etc/kolla/globals.yml"
      ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE} | grep "inet" | awk '{print $2}' | cut -d/ -f1)"
      BASE="$(echo $ADDRESS | cut -d. -f 1,2,3)"
      VIP=$(echo "${BASE}.254")

      sed -i "s/^kolla_internal_vip_address:.*/kolla_internal_vip_address: ${VIP}/g" ${GLOBALS_FILE}
      sed -i "s/^network_interface:.*/network_interface: ${NETWORK_INTERFACE}/g" ${GLOBALS_FILE}
      sed -i "s/^neutron_external_interface:.*/neutron_external_interface: ${NEUTRON_INTERFACE}/g" ${GLOBALS_FILE}
      echo "${ADDRESS} localhost" >> /etc/hosts

      mkdir -p /etc/kolla/config/nova/
    tee > /etc/kolla/config/nova/nova-compute.conf <<-EOF
[libvirt]
virt_type=qemu
EOF

      kolla-genpwd
      sed -i "s/^keystone_admin_password:.*/keystone_admin_password: Koll@0penst@ck" /etc/kolla/passwords.yml
      kolla-ansible prechecks
      kolla-ansible pull
      kolla-ansible deploy

      echo "Login using http://127.0.0.1:8080/ with admin as username and $(cat /etc/kolla/passwords.yml | grep "keystone_admin_password" | awk '{print $2}') as password"
