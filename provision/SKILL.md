---
name: provision
description: Get a throwaway Debian LXC on Hendrik's Proxmox over HTTP, or destroy one. Use when a task needs a real Linux box (building a .deb, testing a service, anything that must not run in this container) and no box exists yet, and when finishing with one. Also covers why a box cannot reach the hypervisor.
---

# Provisioning a test box

A broker on the Proxmox node makes Debian 13 LXCs on request. Claude has no other
access to Proxmox: no SSH to the node, no PVE API, no web UI.

## Credentials

Two lines in `/workspace/.claude-provision-token` (`C:\.claude-provision-token`):

```
PROVISION_URL=http://<node-ip>:8099
PROVISION_TOKEN=<token>
```

The file is written on Windows, so it has CRLF line endings and must be stripped
before sourcing or every URL is malformed:

```bash
set -a; . <(tr -d '\r' < /workspace/.claude-provision-token); set +a
```

If the file is missing, the broker is not installed on this machine, so ask Hendrik
rather than looking for another route onto the node.

## Calls

```bash
set -a; . <(tr -d '\r' < /workspace/.claude-provision-token); set +a
AUTH="Authorization: Bearer $PROVISION_TOKEN"
KEY=~/.ssh/provision_ed25519
[ -f $KEY ] || ssh-keygen -t ed25519 -N '' -C claude-provision -f $KEY

curl -sS -H "$AUTH" "$PROVISION_URL/boxes"

curl -sS -H "$AUTH" -X POST "$PROVISION_URL/box" --max-time 240 \
  -d "{\"name\":\"fwbox-test2\",\"recipe\":\"lxc-small\",\"sshkey\":\"$(cat $KEY.pub)\"}"

curl -sS -H "$AUTH" -X DELETE "$PROVISION_URL/box/9000"
```

Create blocks until port 22 answers, about 10 seconds in practice, and returns `vmid`,
`name` and `ip`. Then `ssh -i $KEY root@<ip>`.

The key is container-local. After a container rebuild it is gone and boxes made with
the old one are unreachable, so destroy and recreate them rather than hunting for a
way back in.

## Rules

- Reposting the same name returns the existing box. On a timeout, repost the same
  name, never a new one.
- Cap is five boxes in any state. On a 409, show Hendrik the list and ask which to
  destroy. Do not work around the cap.
- Destroy the box when the work is done. Nothing expires on its own.
- Three recipes, all DHCP on the LAN, sizes fixed: `lxc-small` is 2 cores, 2 GB,
  16 GB; `lxc-medium` is 2 cores, 4 GB, 40 GB; `lxc-large` is 4 cores, 8 GB, 80 GB.
  Take small unless the work needs the room. Anything bigger, a KVM guest, or Docker
  inside the box needs a new recipe on the node, which is Hendrik's job.

## What the box cannot do

Outbound traffic to the Proxmox node and the NAS is dropped by the firewall group, so
no 8006 and no SSH to the hypervisor from inside. Verified: those ports time out while
the rest of the LAN, DNS, apt and the internet work normally. That is deliberate, do not
try to route around it.

It is an unprivileged LXC: 512 MB of cgroup swap and no way to add more (`swapon` on a
swapfile fails), no nftables, no wireguard, no Docker. Memory-hungry builds need `-j2`,
and kernel or firewall work needs a real VM, which this broker cannot make.
