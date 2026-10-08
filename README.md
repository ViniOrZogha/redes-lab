# Minha pequena internet

Laboratório do trabalho semestral de **Redes e Sistemas Distribuídos** —
Prof. Me. Luiz Ricardo Mantovani da Silva.

Uma topologia só, que cresce ao longo do semestre: começa com duas redes que
não se falam e termina com um serviço replicado, roteamento que se refaz
sozinho e a demonstração de por que uma senha não deve viajar sem proteção.

Tudo roda no **Google Cloud Shell**, que é gratuito, não pede cartão de crédito
e dá a cada aluno uma máquina Linux com root só dela.

---

## Começando

Construa a imagem do laboratório — uma vez por sessão do Cloud Shell:

```bash
make base
```

Suba a topologia da primeira entrega:

```bash
make up E=1
```

Rode as provas:

```bash
make verificar E=1
```

`make verificar` **começa vermelho de propósito**. O laboratório vem
incompleto: o roteiro de verificação é o enunciado de verdade, e o trabalho é
levá-lo ao verde.

Enunciado de cada entrega em [`entregas/`](entregas/).

---

## As cinco entregas

| # | Semana | Tema | Vale |
|---|---|---|---|
| [E1](entregas/E1.md) | 6 | Dois segmentos e um serviço | 0,8 |
| [E2](entregas/E2.md) | 9 | O roteador e o encapsulamento | 1,4 |
| [E3](entregas/E3.md) | 11 | O serviço não pode cair | 1,2 |
| [E4](entregas/E4.md) | 12 | A rota se refaz sozinha | 1,2 |
| — | 14 | Apresentação | 1,4 |
| [E5](entregas/E5.md) | 13 | O pacote entrega o segredo · **Cartilha** | **2,0 (Extensão)** |

E1–E4 e a apresentação compõem os 6,0 de avaliação prática. E5 é a atividade
de extensão, com nota escalonada em 1,2 / 1,7 / 2,0.

---

## Regras do jogo

**A entrega é o repositório, nunca o ambiente.** A correção é feita clonando o
repositório do grupo numa Cloud Shell limpa e rodando `make up` e
`make verificar`. Se não subir lá, não entregou.

**Evidência é obrigatória.** `make evidencias E=<n>` grava a saída da
verificação; os `.pcap` das entregas 2 e 5 vão junto. Isso é versionado — nunca
apaguem a pasta `evidencias/`.

**Imagem pequena.** A máquina do Cloud Shell é efêmera e recicla o cache de
imagens: só a pasta pessoal (5 GB) sobrevive. Por isso a base é Alpine.

**Nada de varredura de rede.** Os termos de uso do Cloud Shell proíbem
explicitamente varredura, e a conta que descumprir é desligada. Todo o trabalho
aqui é captura passiva dentro da rede virtual do próprio grupo — o que é outra
coisa, e é permitido.

---

## Para o professor

Antes de liberar para a turma, uma vez, numa Cloud Shell limpa:

```bash
make autoteste
```

Confere as quatro coisas de que o laboratório depende e que documentação
nenhuma garante: criação de bridge com sub-rede própria, `tcpdump` com
`NET_RAW` efetivo, `net.ipv4.ip_forward` por contêiner, e o pacote `bird` no
Alpine (só a E4 depende dele).

### Botão "Abrir no Cloud Shell"

Para cada entrega, na página do trabalho:

```
https://shell.cloud.google.com/cloudshell/editor
  ?cloudshell_git_repo=https://github.com/LuizRMSilva1973/redes-lab
  &cloudshell_tutorial=entregas/E1.md
  &show=ide%2Cterminal
```

O aluno cai no terminal com o repositório clonado e o enunciado aberto como
roteiro guiado ao lado. Trocar `E1.md` pela entrega da vez.

O repositório precisa estar em **GitHub ou Bitbucket**, público.

### Correção

```bash
git clone <repo-do-grupo> && cd <repo> && make up E=2 && make verificar E=2
```

Os roteiros imprimem o valor observado em cada ponto, não só passou/falhou —
dá para corrigir lendo a saída.

---

## Entrega 1 — plano de endereçamento

Duas sub-redes /24, uma por segmento, sem rota entre elas.

| Segmento | Sub-rede     | Máscara       | Endereços totais | Utilizáveis | Faixa utilizável         |
|----------|--------------|---------------|-------------------|-------------|---------------------------|
| A        | 10.0.10.0/24 | 255.255.255.0 | 256               | 254         | 10.0.10.1 – 10.0.10.254  |
| B        | 10.0.20.0/24 | 255.255.255.0 | 256               | 254         | 10.0.20.1 – 10.0.20.254  |

Conta: /24 reserva 8 bits para host → 2^8 = 256 endereços; descontam-se
`.0` (rede) e `.255` (broadcast), sobrando 254 utilizáveis por sub-rede.

| Contêiner  | Segmento | Endereço IP | Papel                       |
|------------|----------|-------------|------------------------------|
| e1-host-a1 | A        | 10.0.10.10  | host                         |
| e1-host-a2 | A        | 10.0.10.11  | host                         |
| e1-srv-a   | A        | 10.0.10.20  | servidor HTTP (porta 8080)   |
| e1-host-b1 | B        | 10.0.20.10  | host                         |
| e1-host-b2 | B        | 10.0.20.11  | host                         |

### Por que A não alcança B

Cada contêiner teve a rota padrão removida (`ip route del default`), então
cada host só conhece a rota direta da própria sub-rede. As redes `seg-a` e
`seg-b` são bridges Docker distintas, sem gateway nem encaminhamento entre
elas. Ao tentar `host-a1 → host-b1`, o kernel não encontra rota para
10.0.20.0/24 na tabela local e responde de imediato com **"Network is
unreachable"** — um erro de camada 3 gerado localmente, sem sequer enviar
pacote.

Isso é diferente de um timeout: se houvesse rota mas o destino estivesse
apenas desligado, o ping ficaria esperando resposta. A mensagem específica
comprova que o isolamento é estrutural (ausência de rota entre as sub-redes),
não um acidente de host fora do ar — coerente com o teste feito também no
sentido inverso (`host-b* → srv-a`, `curl` sem resposta, rc=7).

## Entrega 2  — Relatório Técnica

### Comprovação de Mudança de Cabeçalhos (Wireshark)
Abaixo estão os prints comparativos dos pacotes ICMP Request capturados nos dois segmentos de rede:

* **Segmento A:
* **Segmento B:

### Por que o MAC muda e o IP não?
O endereço **IP não muda** porque opera na Camada 3 (Rede) e possui escopo **global**, servindo para identificar de forma imutável a origem inicial (`10.0.10.10`) e o destino final (`10.0.20.10`) da comunicação através de múltiplos roteadores. 

Já o endereço **MAC muda** a cada salto porque opera na Camada 2 (Enlace) e possui escopo **local**, sendo válido apenas dentro de um mesmo segmento físico. Quando o pacote cruza o roteador, este remove o cabeçalho Ethernet do `seg-a` (onde o destino era o próprio roteador) e reconstrói um novo cabeçalho para o `seg-b`, alterando o MAC de origem para a sua própria interface de saída (`10.0.20.254`) e o MAC de destino para o endereço físico do `host-b1`.
