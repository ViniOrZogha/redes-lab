#!/bin/sh
# Provas da Entrega 1. Testa os DOIS lados: o que tem de funcionar e o que
# tem de falhar. Um teste só do lado negativo passaria com tudo desligado.
falhas=0
ok()  { printf '  \033[32m OK \033[0m %s\n' "$1"; }
nok() { printf '  \033[31mNAO \033[0m %s\n' "$1"; falhas=$((falhas+1)); }
obs() { printf '        observado: %s\n' "$1"; }

echo
echo "=== ENTREGA 1 — dois segmentos e um serviço ==="
echo
# Qual arquivo estamos mesmo lendo, e o que ele declara. Sem isto, editar uma
# pasta e rodar o make em outra (o --force_new_clone cria redes-lab-0, -1, -2…)
# aparece só como "contêiner não existe", e a busca começa no lugar errado.
DECL=$(docker compose config --services 2>/dev/null | tr '\n' ' ')
echo "  arquivo lido:        $(pwd)/docker-compose.yml"
echo "  serviços declarados: ${DECL:-<não consegui ler o arquivo>}"
if [ -z "$DECL" ]; then
  obs "$(docker compose config 2>&1 | head -2 | tr '\n' ' ')"
fi
echo

for c in e1-host-a1 e1-host-a2 e1-srv-a e1-host-b1 e1-host-b2; do
  if docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
    ip=$(docker exec "$c" sh -c "ip -4 -o addr show eth0 | awk '{print \$4}'" 2>/dev/null)
    ok "contêiner $c no ar"; obs "$ip"
  else
    nok "contêiner $c NÃO existe ou não está no ar"
    svc=${c#e1-}
    if ! echo " $DECL " | grep -q " $svc "; then
      # Causa mais provável, e a mais traiçoeira: o YAML ACEITA um nome de
      # serviço indentado a mais e o engole dentro do serviço anterior, sem erro.
      obs "o docker-compose.yml NEM DECLARA o serviço '$svc'"
      obs "confira a INDENTAÇÃO: nome de serviço leva 2 espaços, igual a 'host-a1' — com 4 o YAML o esconde dentro do serviço de cima, calado"
      obs "e confirme que você editou o arquivo DESTA pasta: $(pwd)"
    elif ! docker inspect "$c" >/dev/null 2>&1; then
      # Caso mais comum depois de editar o arquivo: o serviço já está declarado,
      # mas o contêiner nunca foi criado porque o `up` não rodou de novo.
      obs "o serviço ESTÁ declarado, mas o contêiner nunca foi criado"
      obs "você editou o docker-compose.yml depois do último 'make up' — rode: make up E=1"
    else
      # Contêiner existe e está parado: aí sim o log dele é a pista. Sem esta
      # distinção, `docker logs` num contêiner inexistente devolve o erro do
      # daemon e ele aparecia como se fosse a última saída do programa.
      log=$(docker logs --tail 2 "$c" 2>&1 | tr '\n' ' ')
      [ -n "$log" ] && obs "última saída do contêiner: $log" || obs "contêiner criado e parado, sem log"
    fi
  fi
done
echo

# --- lado positivo: dentro do mesmo segmento tem de funcionar ---
o=$(docker exec e1-host-a1 ping -c1 -W1 10.0.10.11 2>&1 || true)
case "$o" in *" 0% packet loss"*) ok "A: host-a1 alcança host-a2";
    obs "$(echo "$o" | sed -n '2p')";; *) nok "A: host-a1 NÃO alcança host-a2"; obs "$(echo "$o" | tail -2 | tr '\n' ' ')";; esac

o=$(docker exec e1-host-b1 ping -c1 -W1 10.0.20.11 2>&1 || true)
case "$o" in *" 0% packet loss"*) ok "B: host-b1 alcança host-b2";
    obs "$(echo "$o" | sed -n '2p')";; *) nok "B: host-b1 NÃO alcança host-b2"; obs "$(echo "$o" | tail -2 | tr '\n' ' ')";; esac

o=$(docker exec e1-host-a2 curl -s -m 2 http://10.0.10.20:8080/ 2>&1 || true)
case "$o" in *"srv-a"*) ok "A: host-a2 obtém a página do servidor"; obs "$o";;
    *) nok "A: host-a2 não obteve a página"; obs "${o:-<vazio>}";; esac
echo

# --- lado negativo: e tem de falhar PELO MOTIVO CERTO ---
o=$(docker exec e1-host-a1 ping -c1 -W1 10.0.20.10 2>&1 || true)
case "$o" in
  *nreachable*) ok "isolamento: A não alcança B (camada 3)"; obs "$(echo "$o" | grep -i unreach | head -1)";;
  *) nok "isolamento: falhou, mas NÃO por 'Network is unreachable'"; obs "$(echo "$o" | tail -2 | tr '\n' ' ')";;
esac

# Este teste SÓ vale se host-b1 existir. Sem essa trava ele ficava verde
# justamente porque o contêiner não existia — um curl que nunca aconteceu
# "provando" isolamento. Ausência de sinal não é prova.
if docker inspect -f '{{.State.Running}}' e1-host-b1 2>/dev/null | grep -q true; then
  o=$(docker exec e1-host-b1 curl -s -m 2 http://10.0.10.20:8080/ 2>&1; echo "rc=$?")
  case "$o" in *"srv-a"*) nok "isolamento QUEBRADO: B chegou no servidor de A"; obs "$o";;
      *) ok "isolamento: B não chega no servidor de A"; obs "curl terminou sem resposta ($(echo "$o" | tail -1))";; esac
else
  nok "isolamento B→A: NÃO AVALIADO"
  obs "host-b1 não está no ar; sem ele este teste não prova nada"
fi

echo
if [ "$falhas" -eq 0 ]; then
  printf '\033[32mENTREGA 1 COMPLETA\033[0m — gere as evidências: make evidencias E=1\n\n'
else
  printf '\033[31m%s prova(s) ainda vermelha(s).\033[0m É esperado no começo: seu trabalho é deixar tudo verde.\n\n' "$falhas"
  exit 1
fi
