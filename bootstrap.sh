#!/bin/bash
set -e
checkout_dir=/opt
mkdir -p /tmp/bootstrap-rpco-inv
mkdir -p /tmp/bootstrap-rpco-inv/group_vars
mkdir -p /tmp/bootstrap-rpco-inv/host_vars
cat > /tmp/bootstrap-rpco-inv/group_vars/all.yml << EOF
---
bootstrap_host_data_disk_min_size: 30
bootstrap_host_aio_config: false
EOF
cat > /tmp/bootstrap-rpco-inv/group_vars/swift.yml << EOF
---
swift_conf_overrides:
  global_overrides:
    swift:
      part_power: 8
      storage_network: 'br-storage'
      replication_network: 'br-storage'
      drives:
        - name: disk1
        - name: disk2
        - name: disk3
      mount_point: /srv
      storage_policies:
        - policy:
            name: default
            index: 0
            default: True

  swift-proxy_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  swift_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

user_variables_overrides_swift:
    glance_swift_store_auth_address: '{{ keystone_service_internalurl }}'
    glance_swift_store_user: 'service:glance'
    glance_swift_store_key: '{{ glance_service_password }}'
    glance_swift_store_region: RegionOne
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE1_NAME%%.yml << EOF
---
bootstrap_host_aio_config: true

openstack_user_config_overrides:
  cidr_networks:
    container: 172.29.236.0/22
    snet: 172.29.248.0/22
    tunnel: 172.29.240.0/22
    storage: 172.29.244.0/22

  used_ips:
    - 172.29.236.1,172.29.236.50
    - 172.29.244.1,172.29.244.50

  global_overrides:
    internal_lb_vip_address: %%NODE3_IP%%
    external_lb_vip_address: %%EXTERNAL_VIP_IP%%
    tunnel_bridge: "br-vxlan"
    management_bridge: "br-mgmt"
    provider_networks:
      - network:
          group_binds:
            - all_containers
            - hosts
          type: "raw"
          container_mtu: 1450
          container_bridge: "br-mgmt"
          container_interface: "eth1"
          container_type: "veth"
          ip_from_q: "container"
          is_container_address: true
          is_ssh_address: true
      - network:
          group_binds:
            - glance_api
            - cinder_api
            - cinder_volume
            - nova_compute
          type: "raw"
          container_mtu: 1450
          container_bridge: "br-storage"
          container_interface: "eth2"
          container_type: "veth"
          ip_from_q: "storage"
      - network:
          group_binds:
            - glance_api
            - nova_compute
            - neutron_linuxbridge_agent
          type: "raw"
          container_mtu: 1450
          container_bridge: "br-snet"
          container_interface: "eth3"
          container_type: "veth"
          ip_from_q: "snet"
      - network:
          group_binds:
            - neutron_linuxbridge_agent
          container_bridge: "br-vxlan"
          container_interface: "eth4"
          container_type: "veth"
          ip_from_q: "tunnel"
          type: "vxlan"
          range: "10:1000"
          net_name: "vxlan"
      - network:
          group_binds:
            - neutron_linuxbridge_agent
          container_bridge: "br-vlan"
          container_interface: "eth5"
          container_type: "veth"
          type: "flat"
          net_name: "flat"

  shared-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
      affinity:
        utility_container: 0
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%
      affinity:
        utility_container: 0

  os-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  storage-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  repo-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  identity_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  compute_hosts:
    %%NODE4_NAME%%:
      ip: %%NODE4_IP%%
    %%NODE5_NAME%%:
      ip: %%NODE5_IP%%

  log_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%

  network_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

  haproxy_hosts:
    %%NODE3_NAME%%:
      ip: %%NODE3_IP%%

user_variables_overrides_defaults:
  nova_virt_type: qemu
  keystone_wsgi_processes: 4
  glance_default_store: %%GLANCE_DEFAULT_STORE%%
  glance_swift_store_auth_address: '{{ rackspace_cloud_auth_url }}'
  glance_swift_store_user: '{ rackspace_cloud_tenant_id }}:{{ rackspace_cloud_username }}'
  glance_swift_store_key: '{{ rackspace_cloud_password }}'
  glance_swift_store_region: %%GLANCE_SWIFT_STORE_REGION%%
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE2_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE3_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE4_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE5_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false
EOF
cat > /tmp/bootstrap-rpco-inv/hosts << EOF
%%NODE1_NAME%% ansible_ssh_host=%%NODE1_IP%%
%%NODE2_NAME%% ansible_ssh_host=%%NODE2_IP%%
%%NODE3_NAME%% ansible_ssh_host=%%NODE3_IP%%
%%NODE4_NAME%% ansible_ssh_host=%%NODE4_IP%%
%%NODE5_NAME%% ansible_ssh_host=%%NODE5_IP%%
EOF
if [ %%DEPLOY_SWIFT%% == yes ]; then
  echo '[swift]
all
' >> $BOOTSTRAPINVDIR/hosts
pushd $checkout_dir
  # clone parent repo, but don't initialise submodule yet
  if [ ! -e ${checkout_dir}/rpc-openstack ]; then
    git clone -b %%RPC_OPENSTACK_GIT_VERSION%% %%RPC_OPENSTACK_GIT_REPO%%
  fi

  cd ${checkout_dir}/rpc-openstack

  # if we want to use a different submodule repo/sha
  if [ ! -z %%OS_ANSIBLE_GIT_VERSION%% ]; then
    git config --file=.gitmodules submodule.openstack-ansible.url %%OS_ANSIBLE_GIT_REPO%%
    git submodule update --init
    pushd openstack-ansible
      git checkout %%OS_ANSIBLE_GIT_VERSION%%
    popd
  # otherwise just use the submodule sha specified by parent
  else
    git submodule update --init
  fi
  if [ ! -z %%GERRIT_REFSPEC%% ]; then
    pushd openstack-ansible
      # Git creates a commit while merging so identity must be set.
      git config --global user.name "Hot Hot Heat"
      git config --global user.email "flaming@li.ps"
      git fetch https://review.openstack.org/openstack/openstack-ansible %%GERRIT_REFSPEC%%
      git merge FETCH_HEAD
    popd
  fi
popd
pushd $checkout_dir/rpc-openstack/openstack-ansible
  scripts/bootstrap-ansible.sh
popd
pushd /opt/rpc-openstack/openstack-ansible/tests
  ansible-playbook -i /tmp/bootstrap-rpco-inv/hosts bootstrap-aio.yml
popd
