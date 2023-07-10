# ansible-role-hetzner-encrypted-rootfs

This role bootstraps a Hetzner cloud VM with Debian Bookwork (12.0) and an encrypted rootfs with an embedded Dropbear SSH server within the initramfs.
The role can be easily adjusted and used for a different Debian-based distro like Ubuntu 22.04 (see ``vars`` directory).
However, using it for older versions, e.g., Debian Buster, will require to adjust the template-scripts.
Mainly, the path changed from ``/etc/dropbear-initramfs`` to ``/etc/dropbear/initramfs`` beginning with Debian 12.

The role is technically not idempotent.
It copies around bash scripts and executes them afterwards.

This role re-uses the rescue mode ``installimage`` functionality for rootfs encryption.


## What it does

* In copies a ``install_image.conf`` to rescue image. And sets following variables from vars.
  * hddpw (**BEWARE**, it is stored inside /tmp dir on the rescue image during install)
  * inventory\_hostname (hostname from Ansible's hosts file)
  * hetzner\_image (see ``vars/main.yaml``)
* The ssh pubkey from the root user in you set in the rescue mode, is used for
  * root user in the installed VM and
  * root user for dropbear initramfs
  * The host\_key is the same for Dropbear AND OpenSSH, which eliminates fiddeling with ``known\_hosts`` file and is more secure.
* Set the SSH port for Dropbear initramfs and OpenSSH server inside the VM's sshd\_config
* ``dd`` with /dev/urandom onto /dev/sda

## Prerequisites

Your VM must be booted into Hetzner's rescue mode.
Note, Hetzner rescue mode will auto-generate SSH host keys on boot, you'll have to accept and delete them on your local machine after the install inside the ``known\_hosts`` file.
On first boot after install, use ``ssh-keyscan``.
The following files-folder structure inside ANSIBLE\_HOME is expected to enable predefined hostkeys.

```
├── hosts_crypted_rootfs
├── files
│   ├── example.hostname.com
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

Create the host key.

```bash
ssh-keygen -t ed25519 -f $ANSIBLE_HOME/files/example.hostname.com/ssh_host_ed25519_key
```

Encrypt your priv/host key.

```bash
ansible-vault encrypt --vault-password-file "$ANSIBLE_HOME/.vault_secret" $ANSIBLE_HOME/files/example.hostname.com/ssh_host_ed25519_key
```

Create your rootfs password.

```bash
ansible-vault encrypt_string --vault-password-file "$ANSIBLE_HOME/.vault_secret" "w00fw00fSECRET-REPLACE-ME" --name "hddpw" >> $ANSIBLE_HOME/host_vars/example.hostname.com.yaml
```

Set your SSH port (otherwise 22 is used as default).

```bash
echo "ssh_port: 2222" >> $ANSIBLE_HOME/group_vars/all/main.yml
```

Or locally for a destinct VM.

```bash
echo "ssh_port: 2222" >> $ANSIBLE_HOME/host_vars/example.hostname.com.yml
```

In case you are not executing your playbooks with root, for this role you have to, unfortunately.
This is required for rsync to preserve file permissions and UIDs of the rootfs backup.

```bash
export HOST=example.hostname.com
export ANSIBLE_HOME=path/to/ansible/root

ansible-playbook --vault-password-file $ANSIBLE_HOME/.vault_secret\
$ANSIBLE_HOME/hetzner_crypted_rootfs.yml\
-i $ANSIBLE_HOME/crypted_rootfs_hosts\
--limit $HOST
```

## Credits

The rfc3442 hook is from https://community.hetzner.com/tutorials/install-ubuntu-2004-with-full-disk-encryption.