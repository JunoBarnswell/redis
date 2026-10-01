#!/usr/bin/env bash
set -euo pipefail
setup_dir=/workspace/redis-onboarding
repo_dir=/workspace/redis
for tool in gcc g++ make tclsh pkg-config openssl python3 apt-get dpkg-deb; do
  command -v "$tool" >/dev/null
done
pkg-config --exists openssl
mkdir -p "$setup_dir/apt/lists/partial" "$setup_dir/apt/cache/archives/partial" "$setup_dir/packages" "$setup_dir/tcl"
cat > "$setup_dir/apt/sources.list" <<'SOURCES'
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main
SOURCES
apt_options=(-o Dir::Etc::parts=- -o "Dir::Etc::sourcelist=$setup_dir/apt/sources.list" -o Dir::Etc::sourceparts=- -o "Dir::State::lists=$setup_dir/apt/lists" -o "Dir::Cache=$setup_dir/apt/cache" -o APT::Update::Error-Mode=any)
apt-get "${apt_options[@]}" update
package_dir=$(mktemp -d "$setup_dir/packages/download.XXXXXX")
cd "$package_dir"
apt-get "${apt_options[@]}" download tclx8.4 tcl-tls
for package in ./*.deb; do dpkg-deb -x "$package" "$setup_dir/tcl"; done
# Debian's Tclx index uses a system-absolute path. Relocate only this
# extracted local package index, leaving the repository and system intact.
cat > "$setup_dir/tcl/usr/lib/tclx8.4/pkgIndex.tcl" <<'TCL'
if {![package vsatisfies [package provide Tcl] 8.6]} return
package ifneeded Tclx 8.4 [list load [file join $dir .. libtclx8.4.so.0] Tclx]
TCL
cat > "$setup_dir/env.sh" <<'ENV'
export TCLLIBPATH='/workspace/redis-onboarding/tcl/usr/lib /workspace/redis-onboarding/tcl/usr/lib/tcltk/x86_64-linux-gnu'
ENV
source "$setup_dir/env.sh"
tclsh <<'TCL'
if {[catch {package require Tclx; package require tls} error]} {
  puts stderr $error
  exit 1
}
puts "Tclx and TLS extensions loaded"
TCL
cd "$repo_dir"
make -j4 build redis BUILD_TLS=yes
./src/redis-server --version
