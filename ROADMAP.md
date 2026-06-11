# Agreste Souls — Roadmap do "Mega Jogo"

> Objetivo: Action RPG soulslike 3D, co-op até 4 jogadores, gráficos
> medianos-bonitos (low-poly estilizado + iluminação forte), identidade
> de xilogravura nordestina.

**Política de trabalho:** commit + push ao final de CADA bloco de trabalho.
Trabalho não commitado = trabalho que não existe (lição aprendida em 2026-06-11).

---

## Fase 0 — Fundação ✅ (2026-06-11)
- [x] Projeto 3D (Godot 4.7, Forward+): player, combate, esquiva, Calango, Cangaceiro
- [x] Sistemas: Âmago/Rastro, ciclo lunar, Cruzeiro, HUD, juice (hitstop/shake/partículas)
- [x] Multiplayer co-op até 4 (ENet): menu Solo/Hospedar/Entrar, sync de jogadores,
      inimigos servidor-autoritativos, dano por RPC, portais em rede, relógio lunar sincronizado
- [x] Atmosfera: glow, névoa, SSAO, tonemap ACES, luz lunar dinâmica

## Fase 1 — Validação co-op (próxima)
- [ ] Testar 2 instâncias locais (host + cliente 127.0.0.1) e corrigir o que aparecer
- [ ] Sincronizar estado de animação/ataque dos jogadores remotos (hoje só posição/rotação)
- [ ] Nome flutuante (Label3D) sobre jogadores remotos
- [ ] Tratar morte/respawn em co-op (hoje cada peer respawna o próprio corpo)

## Fase 2 — Gráficos "medianos-bonitos"
- [ ] Substituir cápsulas por modelos low-poly CC0 (KayKit / Quaternius: aventureiros,
      esqueletos, vilarejo, deserto) com AnimationPlayer (idle/walk/attack/death)
- [ ] Conectar os stubs `_play_anim()` às animações reais
- [ ] Chão com textura (terra rachada do sertão) + vegetação (mandacaru, xique-xique)
- [ ] Céu noturno com estrelas + lua visível que muda com a fase
- [ ] Sombra de contato + partículas ambientes (poeira ao vento, vagalumes)

## Fase 3 — Conteúdo
- [ ] 3 biomas (Caatinga profunda, Serra, Vila abandonada) interligados ao Hub
- [ ] 6–8 inimigos (variantes + comportamentos novos: à distância, em bando)
- [ ] 1º boss: Mula Sem Cabeça (evento de Lua Cheia)
- [ ] Menu de evolução de atributos no Cruzeiro (gastar Âmago)

## Fase 4 — Sistemas soulslike
- [ ] Armas (peixeira, facão, zagaia) com movesets diferentes
- [ ] Forja do Benedito (upgrade de armas)
- [ ] Eventos lunares: Boitatá, Corpo-Seco, Saci

## Fase 5 — Multiplayer avançado
- [ ] Lobby com lista de jogadores e nomes escolhidos
- [ ] Reconexão e migração suave de fases
- [ ] Jogar pela internet sem abrir porta (Steam P2P ou serviço de relay/noray)

## Fase 6 — Polimento e lançamento
- [ ] Áudio completo (zabumba/triângulo/sanfona, SFX)
- [ ] Balanceamento, NG+, build de demo (itch.io / Steam)
