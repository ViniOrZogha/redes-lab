#!/bin/sh
# Provas da Entrega 2. A prova central não é "o ping funcionou" — é mostrar
# que o pacote foi ROTEADO: o IP atravessa inalterado, o quadro Ethernet é
# refeito dos dois lados, e o TTL cai de 64 para 63.
falhas=0
ok()  { printf '  \033[32m OK \033[0m %s\n' "$1"; }
nok() { printf '  \033[31mNAO \033[0m %s\n' "$1"; falhas=$((falhas+1)); }
obs() { printf '        observado: %s\n' "$1"; }
iface(){ docker exec "$1" sh -c "ip -4 -o addr show | awk '/$2\//{print \$2}'" 2>/dev/null | head -1; }

echo; echo "=== ENTREGA 2 — o roteador e o encapsulamento ==="; echo

f=$(docker exec e2-router cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
[ "$f" = "1" ] && { ok "roteador com repasse IP ligado"; obs "net.ipv4.ip_forward=$f"; } \
                || { nok "roteador SEM repasse IP"; obs "net.ipv4.ip_forward=$f"; }

IA=$(iface e2-router 10.0.10.254); IB=$(iface e2-router 10.0.20.254)
[ -n "$IA" ] && [ -n "$IB" ] && { ok "roteador com perna nos dois segmentos"; obs "$IA=10.0.10.254  $IB=10.0.20.254"; } \
                             || { nok "roteador não tem as duas pernas"; obs "seg-a=${IA:-ausente} seg-b=${IB:-ausente}"; }
echo

# --- positivo: quem TEM rota atravessa ---
o=$(docker exec e2-host-a1 ping -c1 -W2 10.0.20.10 2>&1 || true)
case "$o" in *" 0% packet loss"*) ok "host-a1 alcança host-b1 (outro segmento)"; obs "$(echo "$o" | sed -n '2p')";;
  *) nok "host-a1 NÃO alcança host-b1 — falta a rota?"; obs "$(echo "$o" | tail -2 | tr '\n' ' ')";; esac

ttl=$(echo "$o" | sed -n 's/.*ttl=\([0-9]*\).*/\1/p' | head -1)
if [ "$ttl" = "63" ]; then ok "o pacote foi ROTEADO (TTL decrementado)"; obs "ttl=$ttl (saiu 64, chegou 63: um salto)"
elif [ "$ttl" = "64" ]; then nok "TTL intacto: isto NÃO passou por roteador"; obs "ttl=$ttl"
else nok "não foi possível ler o TTL"; obs "ttl=${ttl:-ausente}"; fi
echo

# --- controle: quem NÃO tem rota continua sem atravessar ---
o=$(docker exec e2-host-a2 ping -c1 -W2 10.0.20.10 2>&1 || true)
case "$o" in *nreachable*) ok "controle: host-a2 (sem rota) continua isolado"; obs "$(echo "$o" | grep -i unreach | head -1)";;
  *" 0% packet loss"*) nok "controle FALHOU: host-a2 atravessou sem rota — a prova de host-a1 não vale"; obs "$(echo "$o" | sed -n '2p')";;
  *) nok "controle: falhou por outro motivo"; obs "$(echo "$o" | tail -2 | tr '\n' ' ')";; esac
echo

# --- a prova do encapsulamento: mesma carga IP, quadros Ethernet diferentes ---
echo "  capturando nas duas pernas do roteador..."
docker exec e2-router sh -c "rm -f /lab/*.pcap" 2>/dev/null
docker exec -d e2-router sh -c "tcpdump -i $IA -n -e -c 4 -U -w /lab/perna-a.pcap icmp" 2>/dev/null
docker exec -d e2-router sh -c "tcpdump -i $IB -n -e -c 4 -U -w /lab/perna-b.pcap icmp" 2>/dev/null
# Espera as DUAS capturas estarem ouvindo. Tempo fixo faz o ping sair antes do
# tcpdump subir num contêiner novo, e a prova do encapsulamento some sem aviso.
i=0
while [ $i -lt 15 ]; do
  docker exec e2-router sh -c "[ -f /lab/perna-a.pcap ] && [ -f /lab/perna-b.pcap ]" 2>/dev/null && break
  i=$((i+1)); sleep 1
done
sleep 1
docker exec e2-host-a1 ping -c3 -W2 10.0.20.10 >/dev/null 2>&1 || true
sleep 2

docker exec e2-router sh -c "pkill tcpdump" 2>/dev/null; sleep 1

le(){ docker exec e2-router tcpdump -n -e -r "/lab/$1" 2>/dev/null | grep -i "echo request" | head -1; }
LA=$(le perna-a.pcap); LB=$(le perna-b.pcap)
macA=$(echo "$LA" | awk '{print $2}'); macB=$(echo "$LB" | awk '{print $2}')
ipA=$(echo "$LA"  | sed -n 's/.*length [0-9]*: \([0-9.]*\) > .*/\1/p')
ipB=$(echo "$LB"  | sed -n 's/.*length [0-9]*: \([0-9.]*\) > .*/\1/p')

printf '        perna A: %s\n' "${LA:-<nada capturado>}"
printf '        perna B: %s\n' "${LB:-<nada capturado>}"

if [ -z "$ipA" ] || [ -z "$ipB" ]; then
  nok "não capturei o mesmo pacote nas duas pernas"
else
  [ "$ipA" = "$ipB" ] && { ok "o IP de origem ATRAVESSOU inalterado"; obs "$ipA nos dois lados"; } \
                      || { nok "o IP mudou entre as pernas"; obs "A=$ipA  B=$ipB"; }
  [ "$macA" != "$macB" ] && { ok "o quadro Ethernet foi REFEITO em cada segmento"; obs "MAC origem A=$macA  B=$macB"; } \
                         || { nok "o MAC de origem é o mesmo — não houve troca de enlace"; obs "$macA"; }
fi

echo
if [ "$falhas" -eq 0 ]; then
  docker exec e2-router sh -c "cat /lab/perna-a.pcap" > perna-a.pcap 2>/dev/null
  docker exec e2-router sh -c "cat /lab/perna-b.pcap" > perna-b.pcap 2>/dev/null
  printf '\033[32mENTREGA 2 COMPLETA\033[0m — perna-a.pcap e perna-b.pcap salvos aqui. Abra os dois no Wireshark.\n\n'
else
  printf '\033[31m%s prova(s) vermelha(s).\033[0m\n\n' "$falhas"; exit 1
fi
