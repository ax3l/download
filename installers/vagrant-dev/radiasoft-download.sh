#!/bin/bash
#
# Create a Centos or Fedora VirtualBox with guest additions
#
# Usage: curl radia.run | bash -s vagrant-up centos|fedora [guest-name:v.radia.run [guest-ip:10.10.10.10]]
#
vagrant_dev_check() {
    local vdi=$1
    if [[ -z $(type -t vagrant) ]]; then
        install_err 'vagrant not installed. Please visit to install:

http://vagrantup.com'
    fi
    if [[ -d .vagrant ]]; then
        local s=$(vagrant status 2>&1)
        local re=' not created |machine is required to run'
        if [[ ! $s =~ $re ]]; then
            install_err 'vagrant machine exists. Please run: vagrant destroy -f'
        fi
    fi
    vagrant_dev_plugins
    vagrant_dev_vdi_delete "$vdi"
}

vagrant_dev_main() {
    local os=$1 host=${2:-v.radia.run} ip=$3
    local base=${host%%.*}
    if [[ ! $os =~ ^(fedora|centos) ]]; then
        install_err "$os: invalid OS: only fedora or centos are supported"
    fi
    if [[ -z ${vagrant_dev_no_nfs_src+x} ]]; then
        if [[ $os =~ centos ]]; then
            vagrant_dev_no_nfs_src=1
        fi
    fi
    if [[ -z $ip ]]; then
        ip=$(dig +short "$host")
        if [[ -z $ip ]]; then
            install_err "$host: host not found and IP address not supplied"
        fi
    fi
    # Absolute path is necessary for comparison in vagrant_dev_delete_vdi
    local vdi=$PWD/$base-docker.vdi
    echo 'We need access to sudo on your Mac to mount NFS'
    if ! sudo true; then
        install_err 'must have access to sudo'
    fi
    if [[ ! -r /etc/exports ]]; then
        sudo touch /etc/exports
        # vagrant requires /etc/exports readable by an ordinary user
        sudo chmod 644 /etc/exports
    fi
    vagrant_dev_check "$vdi"
    vagrant_dev_vagrantfile "$os" "$host" "$ip" "$vdi" '1'
    vagrant up
    vagrant ssh <<'EOF'
sudo yum install -q -y kernel kernel-devel kernel-headers kernel-tools perl
#perl -pi -e 's{(?<=^SELINUX=).*}{disabled}' /etc/selinux/config
EOF
    vagrant halt
    vagrant_dev_vagrantfile "$os" "$host" "$ip" "$vdi" ''
    vagrant up
    local f
    for f in ~/.gitconfig ~/.netrc; do
        if [[ -r $f ]]; then
            vagrant ssh -c "dd of=$(basename $f)" < "$f" >& /dev/null
        fi
    done
    vagrant ssh <<EOF
export install_server='$install_server' install_channel='$install_channel' install_debug='$install_debug'
curl radia.run | bash -s redhat-dev
EOF
}

vagrant_dev_plugins() {
    local plugins=$(vagrant plugin list)
    local p op
    for p in vagrant-persistent-storage vagrant-vbguest; do
        op=install
        if [[ $plugins =~ $p ]]; then
            op=update
        fi
        vagrant plugin "$op" "$p"
    done
}

vagrant_dev_vagrantfile() {
    local os=$1 host=$2 ip=$3 vdi=$4 first=$5
    local vbguest='' timesync=''
    if [[ -n $first ]]; then
        vbguest='config.vbguest.auto_update = false'
    else
        # https://medium.com/carwow-product-engineering/time-sync-problems-with-vagrant-and-virtualbox-383ab77b6231
        timesync='v.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 5000]'
    fi
    local customizations='' box=$os
    if [[ $os =~ fedora ]]; then
        if [[ $box == fedora ]]; then
            box=fedora/27-cloud-base
        fi
        customizations='
        # Needed for compiling some the larger codes
        v.memory = 8192
        v.cpus = 4
'
    elif [[ $box == centos ]]; then
        box=centos/7
    fi
    local nfs_src=''
    if [[ -z $vagrant_dev_no_nfs_src ]]; then
        nfs_src='
    config.vm.synced_folder "'"$HOME/src"'", "/home/vagrant/src", type: "nfs", mount_options: ["rw", "vers=3", "tcp", "nolock", "fsc", "actimeo=2"]
'
    fi
    cat > Vagrantfile <<EOF
# -*-ruby-*-
Vagrant.configure("2") do |config|
    config.vm.box = "$box"
    config.vm.hostname = "$host"
    config.vm.network "private_network", ip: "$ip"
    config.vm.provider "virtualbox" do |v|
        ${timesync}
        # Fix Mac thunderbolt issue
        v.customize ["modifyvm", :id, "--audio", "none"]
        # https://stackoverflow.com/a/36959857/3075806
        v.customize ["setextradata", :id, "VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled", "0"]
        # If you see network restart or performance issues, try this:
        # https://github.com/mitchellh/vagrant/issues/8373
        # v.customize ["modifyvm", :id, "--nictype1", "virtio"]
        #
        ${customizations}
    end

    # Create a disk for docker
    config.persistent_storage.enabled = true
    # so doesn't write signature
    config.persistent_storage.format = false
    # Clearer to add host name to file so that it can be distinguished
    # in VirtualBox Media Manager, which only shows file name, not full path.
    config.persistent_storage.location = "$vdi"
    # so doesn't modify /etc/fstab
    config.persistent_storage.mount = false
    # use whole disk
    config.persistent_storage.partition = false
    config.persistent_storage.size = 102400
    config.persistent_storage.use_lvm = true
    config.persistent_storage.volgroupname = "docker"
    config.ssh.forward_x11 = false
${vbguest}    # https://stackoverflow.com/a/33137719/3075806
    # Undo mapping of hostname to 127.0.0.1
    config.vm.provision "shell",
        inline: "sed -i '/127.0.0.1.*$host/d' /etc/hosts"
    # Have to use vers=3 b/c vagrant will insert it otherwise. Not sure why.
    config.vm.synced_folder ".", "/vagrant", type: "nfs", mount_options: ["rw", "vers=3", "tcp", "nolock", "fsc", "actimeo=2"]
    ${nfs_src}
end
EOF
}

vagrant_dev_vdi_delete() {
    # vdi might be leftover from previous vagrant up. VirtualBox doesn't
    # destroy automatically.
    local vdi=$1
    if [[ ! -e $vdi ]]; then
        return
    fi
    local uuid=$(vagrant_dev_vdi_find "$vdi")
    if [[ -n $uuid ]]; then
        install_info "Deleting HDD $vdi ($uuid)"
        VBoxManage closemedium disk "$uuid" --delete
    fi
}

vagrant_dev_vdi_find() {
    local vdi=$1
    VBoxManage list hdds | while read l; do
        if [[ ! $l =~ ^([^:]+):[[:space:]]*(.+) ]]; then
            continue
        fi
        case ${BASH_REMATCH[1]} in
            Location)
                if [[ $vdi == ${BASH_REMATCH[2]} ]]; then
                    echo "$u"
                    exit
                fi
                ;;
            UUID)
                u=${BASH_REMATCH[2]}
                ;;
        esac
    done
}

vagrant_dev_main "${install_extra_args[@]}"
