# ansible-role-hetzner-encrypted-rootfs

This role bootstraps a Hetzner cloud VM with Debian Buster (10.4) and an encrypted rootfs with an embedded Dropbear SSH server within the initramfs.
The role can be easily adjusted and used for a different distro, on a regular bare metal machine or even with another hoster.
The platform specific stuff is limited to initial installer task and packages.
For older distros the paths might be an issue, too.
Still, this role is developed and tested with Debian Buster 10.4.
Beware, with older distros you might need the take care of some additional [initramfs issues](https://github.com/HRomie/dropbear-init-fix).

**This is the ugliest role I have ever written!**
It is not idempotent.
It copies around bash scripts and executes them afterwards (for chroot).
There are often commands executed directly, where you would expect a sane person to use Ansible built-in functionality.
The reason is the role performs actions Ansible was not thought for, e.g., running in rescue mode or using LUKS with password over stdin.

## What it does

* Install minimal Debian 10.4 image with Hetzner install scripts.
* Install dependencies for the initramfs.
* Backup the whole rootfs over rsync to YOUR local machine.
* Wipe and overwrite the VM storage.
* Set up partitioning layout.
* Encrypt the rootfs with the desired password.
* Restore the backup to the encrypted rootfs.
* Bootstrap hostkeys for Dropbear and OpenSSH (fixed fingerprints throughout installations).
* Copy over Dropbear configs.
* Generate initramfs.

## Prerequisites

Your VM must be booted in rescue mode respectively another live-image.
The following files-folder structure inside ANSIBLE\_HOME is expected to enable predefined hostkeys.

```
├── crypted_rootfs_hosts
├── files
│   ├── example.hostname.com
│   │   ├── dropbear_ecdsa_host_key
│   │   ├── ssh_host_ed25519_key
│   │   └── ssh_host_ed25519_key.pub
│   ├── [...]
├── hetzner_crypted_rootfs.yml
├── host_vars
│   ├── example.hostname.com.yml
│   └── ...
├── roles
│   ├── hetzner-encrypted-rootfs
│   └── ...
├── ...
```

The SSH pubkey for the booted machine is copied with Hetzner's install script.
That is the reason you won't find it anywhere in this role.
The pubkey for Dropbear, however, you have to take care of yourself.
Put your ecdsa pubkey into ``files/authorized_keys``.

Create the host keys.

```bash
ssh-keygen -t ed25519 -f $ANSIBLE_HOME/files/example.hostname.com/ssh_host_ed25519_key
dropbearkey -t ecdsa -f $ANSIBLE_HOME/files/example.hostname.com/dropbear_ecdsa_host_key
```

Dropbear support for ed25519 was recently added, but it will take some time until this lands into a stable package.
For now, ecdsa seems like a good alternative to dsa and rsa.

Encrypt your priv keys.

```bash
ansible-vault encrypt --vault-password-file "$ANSIBLE_HOME/.vault_secret" $ANSIBLE_HOME/files/example.hostname.com/ssh_host_ed25519_key
ansible-vault encrypt --vault-password-file "$ANSIBLE_HOME/.vault_secret" $ANSIBLE_HOME/files/example.hostname.com/dropbear_ecdsa_host_key
```

Create your rootfs password.

```bash
ansible-vault encrypt_string --vault-password-file "$ANSIBLE_HOME/.vault_secret" "w00fw00fSECRET" --name "hddpw" >> $ANSIBLE_HOME/host_vars/example.hostname.com.yaml
```

Set your SSH port and a backup folder for the temporary rsync backup.

```bash
echo "ssh_port: 2222" >> $ANSIBLE_HOME/group_vars/all/main.yml
echo "backup_path: $ANSIBLE_HOME/somefolder" >> $ANSIBLE_HOME/group_vars/all/main.yml
```
In case you are not executing your playbooks with root, for this role you have to, unfortunately.
This is required for rsync to preserve file permissions and UIDs of the rootfs backup.

```bash
sudo bash -c 'eval "$(ssh-agent -s)"; ssh-add $HOME/.ssh/id_ed25519; ANSIBLE_CONFIG=$ANSIBLE_HOME/ansible.cfg\
  ansible-playbook --vault-password-file $ANSIBLE_HOME/.vault_secret\
  -i $ANSIBLE_HOME/crypted_rootfs_hosts\
  $ANSIBLE_HOME/hetzner_crypted_rootfs.yml\
  --limit $HOST'
```

In case everything went as planned, delete old backup, clean your bash\_history of the vault command (hddpw) and enjoy life.


## Contributions

Always welcome as long as it makes sense for the role's original purpose (bootstrapping).
Please, see LICENSE file before opening a pull request.

Nice to have/known issues:

* Looking at the SSH port with ssh-keyscan I still see the RSA keys for Dropbear. Looks like it generates it uppon start, altough it should not. Not sure how to get rid of it entirely, but matching of ecdsa fingerprint still works.
* The role is really ugly. I am still not sure how to get rid of shell commands. Suggestions to this topic are welcomed.
* Systemd-boot would be interesting, but since Hetzner uses legacy BIOS, GRUB is a mandatory feature for this role. Possible PRs should check for the particular boot-mode.
