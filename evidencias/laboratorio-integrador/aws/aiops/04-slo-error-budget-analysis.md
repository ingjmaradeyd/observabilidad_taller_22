# Análisis SLO y error budget — experimento 2

La ventana del experimento de errores controlados incumplió los objetivos de disponibilidad y tasa de error. La evidencia disponible permite cuantificar esos dos indicadores, pero no la latencia p99 durante el caos.

## Resultado de la ventana

| Indicador | Resultado | Objetivo | Evaluación |
|---|---:|---:|---|
| Solicitudes | 30 | — | Muestra del experimento |
| Respuestas exitosas | 27 | — | — |
| Errores controlados | 3 | — | — |
| Disponibilidad | 90 % | ≥99 % | Incumplido |
| `error_rate` | 10 % | ≤1 % | Incumplido |
| Consumo frente al presupuesto de error | 10 veces el 1 % permitido | 1 % | Excedido |
| Latencia p99 durante caos | No medida | ≤750 ms | No evaluable |

## Evidencia

- `02-aiops-chaos-20260903T064626Z.log`: 30 solicitudes, 27 respuestas HTTP 201 y 3 respuestas HTTP 503 `CHAOS_INJECTED`.
- `03-aiops-cloudwatch-datapoint-20260903T064600Z.log`: `DataServiceChaosErrors=3`; alarma estática en `ALARM`; alarma de anomalías en `OK` por historial insuficiente.
- `../chaos/06-data-service-direct-ip-10pct-20260903T062008Z.log`: confirma el experimento de 10 % de errores con tres fallos controlados.

## Límite de interpretación

La alarma estática confirma detección del datapoint, pero no existe timestamp de transición de alerta utilizable para calcular MTTD. La banda de anomalías no tiene suficiente historial, por lo que su estado `OK` no demuestra detección dinámica. Tampoco se midió p99 durante el caos ni se correlacionó una alerta con `trace_id`; por ello no se declara AIOps completo ni cumplimiento de la rúbrica Excelente.

## Rollback

El rollback fue aplicado; Terraform reportó `2 added, 2 changed, 2 destroyed` y el equipo confirmó posteriormente Service B y `data-service` en `COMPLETED` y estables. El archivo `../chaos/07-chaos-rollback-20260903T062602Z.log` conserva una captura anterior con ambos servicios en `IN_PROGRESS`; no hay una tabla final adicional que deba presentarse como evidencia.

## Key Learnings:

1. Tres errores en 30 solicitudes generan 10 % de `error_rate`, diez veces el presupuesto del 1 %.
2. Un datapoint y una alarma estática en `ALARM` no sustituyen la evidencia de MTTD ni el aprendizaje de una banda de anomalías.
3. Sin p99 durante la ventana de caos no se puede cerrar la evaluación completa del SLO.
