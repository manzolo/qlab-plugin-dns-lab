#!/usr/bin/env bash
# dns-lab run script — boots two VMs for DNS and BIND9 labs

set -euo pipefail

PLUGIN_NAME="dns-lab"
SERVER_VM="dns-lab-server"
CLIENT_VM="dns-lab-client"
SERVER_SSH_PORT=2228
CLIENT_SSH_PORT=2229
DNS_PORT=5354

echo "============================================="
echo "  dns-lab: DNS & BIND9 Lab"
echo "============================================="
echo ""
echo "  This lab creates two VMs:"
echo ""
echo "    1. $SERVER_VM  (SSH port $SERVER_SSH_PORT)"
echo "       Runs BIND9 with forward zone (lab.local) and reverse zone"
echo "       Record types: A, AAAA, CNAME, MX, PTR, NS, TXT, SRV, SOA"
echo ""
echo "    2. $CLIENT_VM  (SSH port $CLIENT_SSH_PORT)"
echo "       Equipped with dig, nslookup, host, whois"
echo "       Query the DNS server at 10.0.2.2:$DNS_PORT"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY=$(get_config DEFAULT_MEMORY 1024)

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by both VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  Both VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for both VMs"
echo ""

# --- DNS Server VM cloud-init ---
info "Creating cloud-init for $SERVER_VM..."

cat > "$LAB_DIR/user-data-server" <<'USERDATA'
#cloud-config
hostname: dns-lab-server
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
package_update: true
packages:
  - bind9
  - bind9-utils
  - dnsutils
  - net-tools
write_files:
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mdns-lab-server\033[0m — \033[1mDNS Server (BIND9)\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mObjectives:\033[0m
          • Learn BIND9 configuration and zone file syntax
          • Understand DNS record types (A, AAAA, CNAME, MX, TXT, SRV, PTR)
          • Manage forward and reverse DNS zones
          • Add, modify, and validate DNS records

        \033[1;33mPre-configured DNS records (lab.local):\033[0m
          \033[0;32mA\033[0m       ns1, web, mail, db, app
          \033[0;32mAAAA\033[0m    web (IPv6)
          \033[0;32mCNAME\033[0m   www → web, ftp → web
          \033[0;32mMX\033[0m      mail (pri 10), mail2 (pri 20)
          \033[0;32mTXT\033[0m     SPF, DMARC
          \033[0;32mSRV\033[0m     _http._tcp, _mysql._tcp
          \033[0;32mPTR\033[0m     reverse lookups for all hosts

        \033[1;33mUseful commands:\033[0m
          \033[0;32msudo named-checkzone lab.local /etc/bind/zones/db.lab.local\033[0m
          \033[0;32msudo named-checkconf\033[0m
          \033[0;32msudo systemctl restart bind9\033[0m
          \033[0;32msudo rndc reload\033[0m
          \033[0;32mdig @localhost lab.local ANY\033[0m
          \033[0;32mcat /etc/bind/zones/db.lab.local\033[0m

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

  - path: /etc/bind/named.conf.options
    content: |
      options {
          directory "/var/cache/bind";
          forwarders {
              8.8.8.8;
              8.8.4.4;
          };
          allow-query { any; };
          recursion yes;
          listen-on { any; };
          listen-on-v6 { any; };
          dnssec-validation auto;
      };

  - path: /etc/bind/named.conf.local
    content: |
      zone "lab.local" {
          type master;
          file "/etc/bind/zones/db.lab.local";
      };

      zone "30.20.10.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/db.10.20.30";
      };

  - path: /etc/bind/zones/db.lab.local
    content: |
      $TTL    604800
      @       IN      SOA     ns1.lab.local. admin.lab.local. (
                                2024010101  ; Serial
                                3600        ; Refresh
                                1800        ; Retry
                                604800      ; Expire
                                86400 )     ; Negative Cache TTL

      ; NS records
      @       IN      NS      ns1.lab.local.

      ; A records
      ns1     IN      A       10.20.30.1
      web     IN      A       10.20.30.10
      mail    IN      A       10.20.30.20
      db      IN      A       10.20.30.30
      app     IN      A       10.20.30.40
      mail2   IN      A       10.20.30.21

      ; AAAA records
      web     IN      AAAA    2001:db8::10

      ; CNAME records
      www     IN      CNAME   web.lab.local.
      ftp     IN      CNAME   web.lab.local.

      ; MX records
      @       IN      MX      10 mail.lab.local.
      @       IN      MX      20 mail2.lab.local.

      ; TXT records
      @       IN      TXT     "v=spf1 mx -all"
      _dmarc  IN      TXT     "v=DMARC1; p=reject"

      ; SRV records
      _http._tcp      IN      SRV     10 0 80 web.lab.local.
      _mysql._tcp     IN      SRV     10 0 3306 db.lab.local.

  - path: /etc/bind/zones/db.10.20.30
    content: |
      $TTL    604800
      @       IN      SOA     ns1.lab.local. admin.lab.local. (
                                2024010101  ; Serial
                                3600        ; Refresh
                                1800        ; Retry
                                604800      ; Expire
                                86400 )     ; Negative Cache TTL

      ; NS records
      @       IN      NS      ns1.lab.local.

      ; PTR records
      1       IN      PTR     ns1.lab.local.
      10      IN      PTR     web.lab.local.
      20      IN      PTR     mail.lab.local.
      30      IN      PTR     db.lab.local.
      40      IN      PTR     app.lab.local.

runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - mkdir -p /etc/bind/zones
  - chown bind:bind /etc/bind/zones
  - chown bind:bind /etc/bind/zones/db.lab.local
  - chown bind:bind /etc/bind/zones/db.10.20.30
  - named-checkzone lab.local /etc/bind/zones/db.lab.local
  - named-checkzone 30.20.10.in-addr.arpa /etc/bind/zones/db.10.20.30
  - named-checkconf
  - systemctl restart bind9
  - systemctl enable bind9
  - echo "=== dns-lab-server VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-server"

cat > "$LAB_DIR/meta-data-server" <<METADATA
instance-id: ${SERVER_VM}-001
local-hostname: ${SERVER_VM}
METADATA

success "Created cloud-init for $SERVER_VM"

# --- Client VM cloud-init ---
info "Creating cloud-init for $CLIENT_VM..."

cat > "$LAB_DIR/user-data-client" <<'USERDATA'
#cloud-config
hostname: dns-lab-client
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
package_update: true
packages:
  - dnsutils
  - net-tools
  - iputils-ping
  - curl
  - whois
write_files:
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mdns-lab-client\033[0m — \033[1mDNS Client / Query VM\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Query the DNS server to explore record types

        \033[1;33mDNS Server:\033[0m  \033[0;32m10.0.2.2\033[0m port \033[0;32m5354\033[0m

        \033[1;33mRecord types to explore:\033[0m
          \033[0;32mA\033[0m       IPv4 address          \033[0;32mAAAA\033[0m    IPv6 address
          \033[0;32mCNAME\033[0m   Canonical name alias  \033[0;32mMX\033[0m      Mail exchange
          \033[0;32mTXT\033[0m     Text (SPF, DMARC)     \033[0;32mSRV\033[0m     Service locator
          \033[0;32mPTR\033[0m     Reverse lookup        \033[0;32mNS\033[0m      Nameserver
          \033[0;32mSOA\033[0m     Start of authority

        \033[1;33mUseful commands:\033[0m
          \033[0;32mdig @10.0.2.2 -p 5354 web.lab.local\033[0m
          \033[0;32mdig @10.0.2.2 -p 5354 lab.local MX\033[0m
          \033[0;32mdig @10.0.2.2 -p 5354 -x 10.20.30.10\033[0m
          \033[0;32mnslookup -port=5354 web.lab.local 10.0.2.2\033[0m
          \033[0;32mhost -p 5354 web.lab.local 10.0.2.2\033[0m

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== dns-lab-client VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-client"

cat > "$LAB_DIR/meta-data-client" <<METADATA
instance-id: ${CLIENT_VM}-001
local-hostname: ${CLIENT_VM}
METADATA

success "Created cloud-init for $CLIENT_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_SERVER="$LAB_DIR/cidata-server.iso"
genisoimage -output "$CIDATA_SERVER" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-server" "meta-data=$LAB_DIR/meta-data-server" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_SERVER"

CIDATA_CLIENT="$LAB_DIR/cidata-client.iso"
genisoimage -output "$CIDATA_CLIENT" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-client" "meta-data=$LAB_DIR/meta-data-client" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_CLIENT"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_SERVER="$LAB_DIR/${SERVER_VM}-disk.qcow2"
if [[ -f "$OVERLAY_SERVER" ]]; then rm -f "$OVERLAY_SERVER"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_SERVER"

OVERLAY_CLIENT="$LAB_DIR/${CLIENT_VM}-disk.qcow2"
if [[ -f "$OVERLAY_CLIENT" ]]; then rm -f "$OVERLAY_CLIENT"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_CLIENT"
echo ""

# =============================================
# Step 5: Start both VMs
# =============================================
info "Step 5: Starting VMs"
echo ""

info "Starting $SERVER_VM (SSH port $SERVER_SSH_PORT, DNS port $DNS_PORT)..."
start_vm "$OVERLAY_SERVER" "$CIDATA_SERVER" "$MEMORY" "$SERVER_VM" "$SERVER_SSH_PORT" \
    "hostfwd=udp::${DNS_PORT}-:53" \
    "hostfwd=tcp::${DNS_PORT}-:53"
echo ""

info "Starting $CLIENT_VM (SSH port $CLIENT_SSH_PORT)..."
start_vm "$OVERLAY_CLIENT" "$CIDATA_CLIENT" "$MEMORY" "$CLIENT_VM" "$CLIENT_SSH_PORT"

echo ""
echo "============================================="
echo "  dns-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  DNS Server VM:"
echo "    SSH:   qlab shell $SERVER_VM"
echo "    Log:   qlab log $SERVER_VM"
echo "    Port:  $SERVER_SSH_PORT"
echo "    DNS:   localhost:$DNS_PORT (UDP+TCP)"
echo "    Zone:  lab.local (forward) + 30.20.10.in-addr.arpa (reverse)"
echo ""
echo "  DNS Client VM:"
echo "    SSH:   qlab shell $CLIENT_VM"
echo "    Log:   qlab log $CLIENT_VM"
echo "    Port:  $CLIENT_SSH_PORT"
echo ""
echo "  Credentials (both VMs):"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Quick DNS test (from client VM):"
echo "    dig @10.0.2.2 -p $DNS_PORT web.lab.local"
echo "    dig @10.0.2.2 -p $DNS_PORT lab.local MX"
echo "    dig @10.0.2.2 -p $DNS_PORT -x 10.20.30.10"
echo ""
echo "  Wait ~90s for boot + package installation."
echo ""
echo "  Stop both VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Stop a single VM:"
echo "    qlab stop $SERVER_VM"
echo "    qlab stop $CLIENT_VM"
echo "============================================="
