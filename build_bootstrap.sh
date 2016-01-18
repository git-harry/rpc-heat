#! /bin/bash

set -e

DIR=bootstrap-rpco-inv
DESTROOT=/tmp
BOOTSTRAPINVDIR=$DESTROOT/$DIR
OUTPUT="#!/bin/bash\nset -e\ncheckout_dir=/opt\n"

for d in $(find $DIR -type d);
do
  OUTPUT+="mkdir -p $DESTROOT/$d\n"
done

for f in $(find $DIR -type f);
do
  OUTPUT+="cat > $DESTROOT/$f << EOF\n"
  OUTPUT+=$(cat $f)
  OUTPUT+="\nEOF\n"
done

OUTPUT+='if [ %%DEPLOY_SWIFT%% == yes ]; then
  echo '\''[swift]\nall\n'\'' >> $BOOTSTRAPINVDIR/hosts
'

OUTPUT+='pushd $checkout_dir
  # clone parent repo, but don'"'"'t initialise submodule yet
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
  ansible-playbook -i '$BOOTSTRAPINVDIR'/hosts bootstrap-aio.yml
popd'

echo -e "$OUTPUT" > bootstrap.sh
