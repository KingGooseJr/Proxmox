#! /bin/bash

# Steps:
# 1: Check for system packages
# 2: Check for 200 ok from download location (backlog)
# 3: Set starting VMID
#     - add warning that vmids in the path of what will be created will be destroyed and ask for continue?
# 4: Set storage pool
# 5: Determine if other vms have same name
#     - add warning that if other vms have same name, they will be destroyed
# 6: Destroy other vms if allowed
# 7: Destroy VMIDs if allowed
# 8: If not allowed to destroy, set random identifier for name
#     - append to current name and then continue
# 9: Create templates

# Options:
# 1: non-destructive
# 2: no-date
# 3: starting vmid
# 4: -y for non interactive
# 5: help/usage

## Add option to set starting vmid then check if following vmids conflict and error
## Add coloring to errors and progress
# qm list | awk '{print $1}' | sort -rn | head -1

while getopts ":hi:rsv:y" o; do
    case "${o}" in
        h) echo "help function";;
        i) declare start_vmid="${OPTARG}";; ## Mutually exclusive with -s
        r) echo "remove date";; ## Mutually exclusive with -s
        s) echo "safe mode/non-destructive";;
        v) echo "You are using ${OPTARG} for your boot disk on these vms";;
        y) echo "non-interactive mode";; ## Mutually exclusive with -s
        *) echo "you broke this";;
    esac
done
# exit 0
function packages_error {
    echo >&2 "ERROR: This script requires the package, ${package} , but it's not installed.  Please install ${package} and rerun.";
    exit 1;
}

function packages_check {
    echo "Verifying necessary packages..."
    sleep 2
    for package in "${packages[@]}"; do 
    type "${package}" >/dev/null 2>&1 || packages_error
    done
    echo "The required packages for running this script are installed."
    sleep 2
}

declare packages=( wget qm pvesm virt-customize )

packages_check

function set_start_vmid {
    echo "Determining currrent max VMID"
    sleep 2
    declare max_vmid=$(qm list | awk '{print $1;}' | sort -rn | head -1)
    [[ -z "${max_vmid}" ]] && echo "There are currently no VMIDs" || echo "The max VMID is: ${max_vmid}"
    sleep 2
    declare -g start_vmid=$(("${max_vmid}"+1000))
    echo "The starting non-conflicting vmid is: ${start_vmid}"
}

[[ -z "${start_vmid}" ]] && set_start_vmid || echo "Using commandline argument of ${start_vmid} as the starting vmid."

sleep 2

## Add warning for interactive mode and take user response

echo "Creating templates serially beginning at VMID: ${start_vmid}"
exit 0

declare images=(
    "ubuntu-jammy-amd64,https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
    "debian-bullseye-amd64,https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    "centos-9-stream-amd64,https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20230501.0.x86_64.qcow2"
    "opensuse-leap-15-5-amd64,https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.x86_64-NoCloud.qcow2"
)

function template_name_error {
    echo >&2 "ERROR: ${template_name} already exists, cannot continue. Exiting now."
    exit 1;
}

function template_name_check  {
    while read template ; do
        if [ "${template_name}" == "${template}" ]; then
            template_name_error
        fi
    done < <(qm list | grep "${template_name}" | awk 'NR>1{print $2}')
}

echo "Checking for name conflicts..."
for element in "${images[@]}"; do
    declare template_name="${element%,*}"
    template_name_check
done
echo "There are no naming conflicts."
exit 0

function create_template {
    qm destroy "${template_id}" --destroy-unreferenced-disks=1
    wget -O /tmp/"${template_name}" "${download_url}"
    virt-customize -a /tmp/"${template_name}" --install qemu-guest-agent
    qm create "${template_id}" --name "${template_name}" --memory 512 --cores 1 --net0 virtio,bridge=vmbr0
    qm importdisk "${template_id}" /tmp/"${template_name}" local-lvm
    qm set "${template_id}" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-"${template_id}"-disk-0 --boot c --bootdisk scsi0 --ide2 local-lvm:cloudinit --serial0 socket --vga serial0 --agent enabled=1
    qm template "${template_id}"
}

for element in "${images[@]}"; do
    declare template_name="${element%,*}"
    declare download_url="${element#*,}"
    echo "${template_name}"
    echo "${download_url}"
    echo "${template_id}"
    create_template
    let "template_id++"
done