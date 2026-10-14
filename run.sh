#!/usr/bin/env bash
# smolvm v1.28.0 test on a GitHub-hosted runner. Each step prints a PASS/FAIL line.
export PATH="$PWD/smolvm-1.28.0-linux-x86_64:$PATH"
pass(){ echo "RESULT PASS: $1"; }; fail(){ echo "RESULT FAIL: $1"; }
ls -l /dev/kvm; sudo chmod 666 /dev/kvm || true
B=https://github.com/smol-machines/smolvm/releases/download/v1.28.0
curl -sLO $B/smolvm-1.28.0-linux-x86_64.tar.gz; curl -sLO $B/checksums.sha256
grep linux-x86_64 checksums.sha256 | sha256sum -c - && tar xzf smolvm-1.28.0-linux-x86_64.tar.gz
smolvm --version
smolvm machine create -n t1 -I alpine --net --cpus 1 --mem 512 -p 18080:8080 -- sh -c 'mkdir -p /w; echo smolvm-ok > /w/index.html; exec busybox httpd -f -p 8080 -h /w' && smolvm machine start -n t1
OUT=$(smolvm machine exec --name t1 -- sh -c 'uname -sr; cat /etc/alpine-release; nproc; grep MemTotal /proc/meminfo') ; echo "$OUT"
echo "$OUT" | grep -q "^3\." && pass "alpine booted in a microVM, guest cat /etc/alpine-release works" || fail "boot/exec"
smolvm machine resize -n t1 --cpus 2; smolvm machine resize -n t1 --mem 1024
OUT2=$(smolvm machine exec --name t1 -- sh -c 'nproc; grep MemTotal /proc/meminfo'); echo "after resize: $OUT2"
echo "$OUT2" | head -1 | grep -q "^2$" && pass "cpu resize 1->2 while running (guest nproc=2)" || fail "cpu resize"
smolvm machine exec --name t1 -- sh -c 'wget -qO- http://127.0.0.1:8080/index.html'
smolvm machine logs -n t1 | tail -5
sleep 2; R=$(curl -s -m 10 http://127.0.0.1:18080/index.html); echo "port18080: $R"
[ "$R" = "smolvm-ok" ] && pass "published port 18080->8080 reaches guest httpd" || fail "port at create"
smolvm machine update -n t1 -p 18081:8080; echo "update-exit=$?"
sleep 3; R2=$(curl -s -m 10 http://127.0.0.1:18081/index.html); echo "port18081: $R2"
[ "$R2" = "smolvm-ok" ] && pass "live port added on running machine (18081)" || fail "live port add (machine update while running)"
R3=$(curl -s -m 10 http://127.0.0.1:18080/index.html); [ "$R3" = "smolvm-ok" ] && pass "original port still works, machine not restarted" || fail "original port after update"
smolvm machine status -n t1
smolvm machine delete -n t1 -f
