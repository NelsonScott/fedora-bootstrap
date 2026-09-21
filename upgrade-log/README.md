# Pre-upgrade snapshot, 2026-08-28
- rpm-qa.tsv: every installed rpm + version before `dnf upgrade` (633 pending).
- pending-updates.txt: what dnf planned to change.
- system.txt: kernel, NVIDIA, GNOME, Secure Boot, firmware, dkms.
- Btrfs read-only snapshots (top-level subvols): snapshots/root-pre-upgrade-2026-08-28, snapshots/home-pre-upgrade-2026-08-28 on /dev/nvme1n1p3.
Rollback single pkg: `dnf downgrade <name>-<EVR>` (old rpm may need koji/rpmfusion archive).
Rollback everything: boot old kernel from GRUB, or mount subvolid=5 and set-default the snapshot.
