#!/usr/bin/env bash

# We need to make our own Profiles. This makes anaconda think we are a Kinoite Install
. /etc/os-release
if [[ "$ID_LIKE" =~ rhel ]]; then
    echo 'VARIANT_ID="kinoite"' >>/usr/lib/os-release
else
    sed -i "s/^VARIANT_ID=.*/VARIANT_ID=kinoite/" /usr/lib/os-release
fi
sed -i "s/^ID=.*/ID=fedora/" /usr/lib/os-release

# Install Anaconda, Webui if >= F42
if [[ "$ID_LIKE" =~ rhel ]]; then
    dnf copr enable -y jreilly1821/anaconda-webui
    dnf install -y anaconda-webui anaconda
    dnf install -y anaconda-live
    HIDE_SPOKE="1"
else
    dnf install -y anaconda-live libblockdev-{btrfs,lvm,dm}
    if [[ "$(rpm -E %fedora)" -ge 42 ]]; then
        # Needed for Anaconda Web UI
        mkdir -p /var/lib/rpm-state
        dnf install -y anaconda-webui
    else
        HIDE_SPOKE="1"
    fi
fi

if [[ "${HIDE_SPOKE:-}" ]]; then
    # Hide Root Spoke
    cat <<EOF >>/etc/anaconda/conf.d/anaconda.conf
[User Interface]
hidden_spokes =
    PasswordSpoke
EOF
fi

# Default Kickstart
cat <<EOF >>/usr/share/anaconda/interactive-defaults.ks
ostreecontainer --url=$imageref:$imagetag --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
EOF

# Install Flatpaks
cat <<'EOF' >>/usr/share/anaconda/post-scripts/install-flatpaks.ks
%post --erroronfail --nochroot
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP /var/lib/flatpak "$target"
%end
EOF

# Disable Fedora Flatpak Repo
cat <<EOF >>/usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%post --erroronfail
systemctl disable flatpak-add-fedora-repos.service
%end
EOF

# Set Anaconda Payload to use flathub
cat <<EOF >>/etc/anaconda/conf.d/anaconda.conf
[Payload]
flatpak_remote = flathub https://dl.flathub.org/repo/
EOF
