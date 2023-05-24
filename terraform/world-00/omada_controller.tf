
module "omada_controller" {
    source = "../modules/qemu-vm/2-9-11"

    ciuser      = "administrator"
    sshkeys     = "/home/gooseubuntu/.ssh/id_rsa.pub"

    config = {
        name        = "omada-controller"
        desc        = "Omada software controller for managing Omada devices. The software can be downloaded [here](https://www.tp-link.com/us/support/download/omada-software-controller/)"
        vmid        = "200"
        target_node = "proxmox-00"
        clone       = "fedora-server-38-amd64"
        cores       = 1
        memory      = 2048
        sockets     = 1
        agent       = 1
        onboot      = true
        
        disk        = {
            backup = false
            type        = "scsi"
            storage     = "local-lvm"
            size        = "32G"
            ssd         = 1
        }
        
        network     = {               
            bridge      = "vmbr0"
            firewall    = true
            model       = "virtio"
        }
    }
}