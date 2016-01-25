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

id: '{{ mgmt_ip.split(".")[-1] }}'

network_interfaces:
  eth1:
    - address_family: 'inet'
      method: 'manual'
  br-snet:
    - address_family: '{{ network_interface_files.eth1.address_family }}'
      method: '{{ network_interface_files.eth1.method }}'
      options: '{{ network_interface_files.eth1.options | combine({"bridge_ports": eth1}) }}'
  eth2:
    - address_family: 'inet'
      method: 'static'
      options:
        address: '{{172.29.232.ID | replace("ID", id)}}'
        netmask: '255.255.252.0'
  vxlan2:
    - address_family: 'inet'
      method: 'manual'
      options:
        pre-up:
          - 'ip link add vxlan2 type vxlan id 2 group 239.0.0.16 ttl 4 dev eth2'
        up:
          - 'ip link set vxlan2 up'
        down:
          - 'ip link set vxlan2 down'
  br-mgmt:
    - address_family: 'inet'
      method: 'static'
      options:
        address: '{{ mgmt_ip }}'
        netmask: '255.255.252.0'
        bridge_ports: 'vxlan2'
  eth4:
    - address_family: 'inet'
      method: 'static'
      options:
        address: '{{ storage_ip }}'
        netmask: '255.255.252.0'
  vxlan4:
    - address_family: 'inet'
      method: 'manual'
      options:
        pre-up:
          - 'ip link add vxlan4 type vxlan id 4 group 239.0.0.16 ttl 4 dev eth4'
        up:
          - 'ip link set vxlan4 up'
        down:
          - 'ip link set vxlan4 down'
  vxlan5:
    # We don't have a dedicated network for this traffic, so we piggy-back on eth4
    - address_family: 'inet'
      method: 'manual'
      options:
        pre-up:
          - 'ip link add vxlan5 type vxlan id 5 group 239.0.0.16 ttl 4 dev eth4'
        up:
          - 'ip link set vxlan5 up'
        down:
          - 'ip link set vxlan5 down'
  br-storage:
    - address_family: 'inet'
      method: 'static'
      options:
        address: '{{ 172.29.244.ID | replace("ID", id) }}'
        netmask: '255.255.252.0'
        bridge_ports: 'vxlan4'
  br-vlan:
    - address_family: 'inet'
      method: 'manual'
      options:
        bridge_ports: 'vxlan5'
  eth3:
    - address_family: 'inet'
      method: 'manual'
  vxlan3:
    - address_family: 'inet'
      method: 'manual'
      options:
        pre-up:
          - 'ip link add vxlan3 type vxlan id 3 group 239.0.0.16 ttl 4 dev eth3'
        up:
          - 'ip link set vxlan3 up'
        down:
          - 'ip link set vxlan3 down'
  br-vxlan:
    - address_family: 'inet'
      method: 'manual'
      options:
        bridge_ports: 'vxlan3'
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
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  swift_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

user_variables_overrides_swift:
    glance_swift_store_auth_address: '{{ keystone_service_internalurl }}'
    glance_swift_store_user: 'service:glance'
    glance_swift_store_key: '{{ glance_service_password }}'
    glance_swift_store_region: RegionOne
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE1_NAME%%.yml << EOF
---
bootstrap_host_aio_config: true

mgmt_ip: '%%NODE1_MGMT_IP%%'
storage_ip: '%%NODE1_STORAGE_IP%%'
tunnel_ip: '%%NODE1_TUNNEL_IP%%'

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
    internal_lb_vip_address: %%NODE3_MGMT_IP%%
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
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
      affinity:
        utility_container: 0
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%
      affinity:
        utility_container: 0

  os-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  storage-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  repo-infra_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  identity_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  compute_hosts:
    %%NODE4_NAME%%:
      ip: %%NODE4_MGMT_IP%%
    %%NODE5_NAME%%:
      ip: %%NODE5_MGMT_IP%%

  log_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%

  network_hosts:
    %%NODE1_NAME%%:
      ip: %%NODE1_MGMT_IP%%
    %%NODE2_NAME%%:
      ip: %%NODE2_MGMT_IP%%
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

  haproxy_hosts:
    %%NODE3_NAME%%:
      ip: %%NODE3_MGMT_IP%%

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

mgmt_ip: '%%NODE2_MGMT_IP%%'
storage_ip: '%%NODE2_STORAGE_IP%%'
tunnel_ip: '%%NODE2_TUNNEL_IP%%'
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE3_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false

mgmt_ip: '%%NODE3_MGMT_IP%%'
storage_ip: '%%NODE3_STORAGE_IP%%'
tunnel_ip: '%%NODE3_TUNNEL_IP%%'
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE4_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false

mgmt_ip: '%%NODE4_MGMT_IP%%'
storage_ip: '%%NODE4_STORAGE_IP%%'
tunnel_ip: '%%NODE4_TUNNEL_IP%%'
EOF
cat > /tmp/bootstrap-rpco-inv/host_vars/%%NODE5_NAME%%.yml << EOF
---
bootstrap_host_aio_config: false

mgmt_ip: '%%NODE5_MGMT_IP%%'
storage_ip: '%%NODE5_STORAGE_IP%%'
tunnel_ip: '%%NODE5_TUNNEL_IP%%'
EOF
cat > /tmp/bootstrap-rpco-inv/hosts << EOF
%%NODE1_NAME%% ansible_ssh_host=%%NODE1_MGMT_IP%%
%%NODE2_NAME%% ansible_ssh_host=%%NODE2_MGMT_IP%%
%%NODE3_NAME%% ansible_ssh_host=%%NODE3_MGMT_IP%%
%%NODE4_NAME%% ansible_ssh_host=%%NODE4_MGMT_IP%%
%%NODE5_NAME%% ansible_ssh_host=%%NODE5_MGMT_IP%%
EOF
if [ %%DEPLOY_SWIFT%% == yes ]; then
  echo '[swift]
all
' >> $BOOTSTRAPINVDIR/hosts
pushd /root/.ssh
  echo "%%PUBLIC_KEY%%" > id_rsa.pub
  echo "%%PRIVATE_KEY%%" > id_rsa
  chmod 600 *
popd
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
