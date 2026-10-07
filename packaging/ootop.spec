Name:           ootop
Version:        0.2.0
Release:        1%{?dist}
Summary:        Sovereign real-time system monitor with systemd slice grouping
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/ootop
Source0:        ootop-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
ootop is a sovereign, capability-bounded real-time system monitor and btop
replacement written in pure openOODA, featuring systemd slice grouping,
ASCII meters and sparklines, dynamic mascot mood art, and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/ootop
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/ootop-uninstall

%files
/usr/bin/ootop
/usr/bin/ootop-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Elevate ootop to S+ tier: 5 structured MCP tools, streaming framing, and compact view

* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign release: real-time dashboard, systemd slices, and MCP stdio surface
