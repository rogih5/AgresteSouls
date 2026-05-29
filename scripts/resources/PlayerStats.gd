class_name PlayerStats
extends Resource

@export_group("Atributos Primários")
## Vitalidade — HP e resistência a veneno/maldição
@export_range(1, 99) var raiz: int = 10
## Energia de combate — Stamina e carga de equipamento
@export_range(1, 99) var folego: int = 10
## Poder bruto — escala armas pesadas, poise
@export_range(1, 99) var braco: int = 10
## Velocidade e crítico — escala armas rápidas, esquiva
@export_range(1, 99) var ginga: int = 10
## Magia elemental — fogo e natureza
@export_range(1, 99) var saberes: int = 10
## Fé e curas — milagres e defesa contra maldição
@export_range(1, 99) var crenca: int = 10
## Sorte — drop rate, críticos, loot lunar
@export_range(1, 99) var mandinga: int = 10

var max_hp: int:
	get: return _calc_max_hp()

var max_stamina: float:
	get: return _calc_max_stamina()

func _calc_max_hp() -> int:
	# +18 HP/pt até 20; +12 até 40; +8 acima (soft cap 40)
	if raiz <= 20:
		return 300 + raiz * 18
	elif raiz <= 40:
		return 660 + (raiz - 20) * 12
	else:
		return 900 + (raiz - 40) * 8

func _calc_max_stamina() -> float:
	# +12/pt até 20; +8 até 30; +4 acima (soft cap 30)
	if folego <= 20:
		return 100.0 + float(folego) * 12.0
	elif folego <= 30:
		return 340.0 + float(folego - 20) * 8.0
	else:
		return 420.0 + float(folego - 30) * 4.0

func get_attack_damage() -> int:
	return 10 + int(float(braco) * 1.5)

func get_critical_chance() -> float:
	return minf(0.05 + float(ginga) * 0.005, 0.75)

func get_critical_damage_mult() -> float:
	return 1.5

## Ginga 20+ concede 1 iframe extra na esquiva
func get_dodge_extra_iframes() -> int:
	return 1 if ginga >= 20 else 0

func get_attack_speed_mult() -> float:
	return 1.0 + float(ginga) * 0.004

func get_loot_chance_bonus() -> float:
	return float(mandinga) * 0.01

func get_poison_resistance() -> float:
	return minf(float(raiz) * 0.02, 0.80)

func get_curse_resistance() -> float:
	return minf(float(raiz) * 0.01, 0.50)

func get_equipment_capacity() -> float:
	return float(folego) * 2.0
