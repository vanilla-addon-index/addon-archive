# ⚙️ Guía de API — Global Translator (v7.1.0 [LEGENDARY-TIER])

El traductor expone métodos públicos y estructuras de datos que pueden ser utilizados por otros componentes del ecosistema **pfUI** o addons de terceros compatibles con WoW Vanilla.

---

## 1. Métodos Públicos

### `pfUI.Translate(text)`
Procesa una cadena de texto, aplica todos los algoritmos activos de la Suite Legendary-Tier (Aislamiento Sintáctico, Token-Bucket, Greedy Matching, Micro-stemmer, Levenshtein Fuzzy matching, CTR Filter, Bilingual rendering y badges) y devuelve su traducción.
*   **`text`** (string): El mensaje original.
*   **Retorno**: (string o nil) Devuelve el texto traducido según las configuraciones activas del usuario, o `nil` si no aplica traducción.

---

## 2. Estructuras de Datos

### `pfUI.translator_dicts`
Contiene los tesauros bidireccionales y trilingües cargados en memoria. Para cada par de idiomas (`es_en`, `en_es`, `zh_en`, `en_zh`, `zh_es`, `es_zh`) existen las siguientes tablas:
*   `[pair]_words`: Tabla de mapeo hash directo para palabras alfanuméricas individuales occidentales.
*   `[pair]_phrases`: Tabla de mapeo hash para frases complejas compuestas, misiones, hechizos e ítems.
*   `[pair]_keys`: Array plano que contiene todas las claves de `[pair]_phrases` ordenadas descendentemente por su longitud de caracteres para priorizar el reemplazo greedy.
*   `[pair]_buckets`: Tabla de indexación asociativa por primera palabra o carácter inicial que alimenta al motor **Token-Bucket**.

### `pfUI.translator_stats`
Tabla de telemetría y rendimiento en tiempo real:
*   `total_in`: Mensajes entrantes que han sido traducidos exitosamente.
*   `total_out`: Mensajes salientes traducidos antes de ser transmitidos al servidor de juego.
*   `cache_hits`: Cantidad de consultas resueltas directamente por la memoria caché LRU (1024 registros de alta capacidad).

---
© 2026 **DarckRovert** — El Séquito del Terror.
*Ingeniería Legendary-Tier.*
