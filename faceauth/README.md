# Face unlock (Howdy) — set up 2026-08-24

Camera: Logitech Brio 4K (IR sensor = 340x340 GREY node), addressed by stable
path /dev/v4l/by-id/usb-046d_Logitech_BRIO_10C26E57-video-index2.

Install: python3-dlib + howdy RPMs from ~/projects/howdy-copr (or the COPR once
published). pip-installing dlib does NOT work: no Linux wheel, its build ignores
CMAKE_ARGS (CUDA breaks vs new gcc), and --user installs are invisible to root,
which is who runs the PAM check.

PAM wiring (deliberately NOT in the shared system-auth, so ssh is never affected):
  /etc/pam.d/sudo         auth sufficient pam_howdy.so   (moot: sudoers has NOPASSWD)
  /etc/pam.d/polkit-1     override file, covers 1Password + all permission popups
  /etc/pam.d/gdm-password covers lock screen AND boot login (keyring nag possible
                          at boot-by-face; acceptable, box reboots ~never)

SELinux: lock screen fails silently without howdy_gdm.te — the xdm_t domain may
open the camera but not mmap it (denied { map } on v4l_device_t). Rebuild+load:
  checkmodule -M -m -o howdy_gdm.mod howdy_gdm.te
  semodule_package -o howdy_gdm.pp -m howdy_gdm.mod && semodule -i howdy_gdm.pp
Denial only visible in journalctl (auditd not collecting), and only with
`semodule -DB` (dontaudit off). Upstream: boltgolt/howdy #1117.

Enrolment: `sudo howdy add` per pose (desk-normal, desk-slouch). Models in
/etc/howdy/models/ — chmod 600 them (upstream #1098 ships world-readable).
