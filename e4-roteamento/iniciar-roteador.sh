#!/bin/sh
# Roda em r1, r2 e r3. A variável ROLE diz qual é.
ip route del default 2>/dev/null || true
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true

# ---------- MODO ATUAL: rotas estáticas ----------
# Funciona: host-a alcança host-b pelo trânsito 1. Mas é uma decisão congelada
# na mão de quem escreveu. Derrube o trânsito 1 e nada se refaz sozinho — o
# desvio por r3 existe, está saudável, e ninguém o usa.


# ---------- TAREFA DO GRUPO ----------
# Troque o bloco acima por roteamento dinâmico: apague o `case` e o `exec` e
# deixe a linha abaixo. Antes, abra bird-r2.conf: falta o `router id` dele.

mkdir -p /run/bird && exec bird -f -c "/lab/bird-$ROLE.conf"
