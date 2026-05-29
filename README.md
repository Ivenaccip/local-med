# local-med

App móvil de primeros auxilios con IA local, completamente offline. El usuario puede consultar protocolos de emergencia desde cualquier lugar, incluso sin señal.

## Idea central

Un modelo de lenguaje corre directamente en el dispositivo — sin servidores, sin internet, sin latencia de red. Diseñado para zonas con conectividad limitada en LATAM.

## Modelo

**Gemma 4 E2B** (Google, 2025)

- Formato: GGUF Q4_K_M (cuantización 4-bit)
- Peso: ~1.3 GB
- RAM requerida: ~1.5 GB en INT4
- Android: 6 GB RAM+, Snapdragon 8-series o equivalente, Android 10+
- iOS: chip A15 Bionic o superior, iOS 16+
- Velocidad de inferencia: 10–25 tokens/segundo en gama alta

## Arquitectura

La app opera en tres capas:

| Capa | Mecanismo | Casos de uso |
|------|-----------|--------------|
| 1 — Crítica | Hardcodeada (sin IA) | RCP adulto/pediátrico, Heimlich, hemorragia severa, posición de recuperación |
| 2 — Conversacional | Gemma 4 E2B fine-tuneado, on-device | Síntomas, procedimientos de segundo nivel, contexto del usuario |
| 3 — RAG local | SQLite + FTS5 + embeddings vectoriales | Consultas complejas, protocolos completos, fallback por baja confianza |

Los protocolos críticos (capa 1) están hardcodeados deliberadamente para eliminar el riesgo de alucinaciones en situaciones de vida o muerte.

## Stack tecnológico

| Componente | Tecnología |
|------------|------------|
| Framework móvil | Flutter |
| Runtime de inferencia | llama.cpp (JNI en Android / Swift bindings en iOS) |
| Embedding on-device | `paraphrase-multilingual-MiniLM-L12-v2` (~117 MB) |
| Base de datos local | SQLite + FTS5 |
| Fine-tuning | QLoRA + Unsloth en Google Colab (GPU T4) |
| Exportación del modelo | GGUF Q4_K_M via llama.cpp |

## Fine-tuning

Pipeline QLoRA con Unsloth sobre Google Colab gratuito (GPU T4, 15 GB VRAM).

```
Configuración LoRA
  r = 16, alpha = 16, dropout = 0
  target_modules: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj

Configuración de entrenamiento
  batch_size = 2, gradient_accumulation_steps = 4  →  batch efectivo = 8
  learning_rate = 2e-4
  epochs = 3
  scheduler = cosine
  optimizer = adamw_8bit
  max_seq_length = 2048
```

Solo se entrenan ~1–3% de los parámetros del modelo base. Tiempo estimado: 20–30 min para 200 ejemplos, 60–90 min para 1,000 ejemplos.

## Dataset

Pares instrucción-respuesta en español, formato Gemma chat (`<start_of_turn>user` / `<start_of_turn>model`).

Fuentes objetivo:
- Protocolos Cruz Roja Internacional
- American Heart Association (AHA) — guías RCP actualizadas
- PHTLS (Prehospital Trauma Life Support)
- Guías de primeros auxilios OPS/OMS

## Descarga inicial

| Componente | Tamaño |
|------------|--------|
| Gemma 4 E2B (GGUF Q4_K_M) | ~1.3 GB |
| Modelo de embeddings | ~117 MB |
| Protocolos + vectores (SQLite) | ~15–20 MB |
| **Total estimado** | **~1.45 GB** |

Descarga obligatoria por WiFi en el primer uso.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Alucinaciones en contexto médico | Protocolos críticos hardcodeados; modelo solo para consultas secundarias |
| Thermal throttling | Pausas entre respuestas; sin inferencia en loop continuo |
| Descarga inicial de 1.45 GB | WiFi obligatoria; descarga incremental si es posible |
| Actualización de protocolos médicos | RAG local actualizable (JSON vía CDN) sin reentrenar el modelo |
| Marco legal (SaMD) | Pendiente: COFEPRIS (México), ARCSA (Ecuador), FDA (EEUU) |

## Roadmap

- [ ] Curar dataset médico (AHA, Cruz Roja, PHTLS) en español
- [ ] Fine-tuning en Colab con dataset real
- [ ] Evaluar modelo fine-tuneado vs modelo base
- [ ] Elegir runtime móvil (Android primero)
- [ ] Integrar GGUF en app móvil — prueba de velocidad en dispositivo real
- [ ] Definir estrategia de actualización de protocolos
- [ ] Consultar marco legal según mercado objetivo
