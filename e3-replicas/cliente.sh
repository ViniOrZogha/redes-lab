#!/bin/sh
# CONTRATO (não mude): escreva na saída padrão só o nome da réplica que
# respondeu e termine com código 0; ou escreva INDISPONIVEL e termine com 1.
# Nunca demore mais que 5 segundos, mesmo com tudo fora do ar.

REPLICAS="10.0.20.21 10.0.20.22 10.0.20.23"
PRAZO=30
tmp=/tmp/cli.$$
mkdir -p "$tmp"

for ip in $REPLICAS; do
  (
    r=$(curl -s -m 2 --connect-timeout 1 "http://$ip:8080/" 2>/dev/null)
    [ -n "$r" ] && echo "$r" > "$tmp/$ip"
  ) &
done

i=0
while [ "$i" -lt "$PRAZO" ]; do
  for f in "$tmp"/*; do
    if [ -s "$f" ]; then
      cat "$f"
      kill $(jobs -p) 2>/dev/null
      rm -rf "$tmp"
      exit 0
    fi
  done
  sleep 0.1
  i=$((i + 1))
done

kill $(jobs -p) 2>/dev/null
rm -rf "$tmp"
echo INDISPONIVEL
exit 1