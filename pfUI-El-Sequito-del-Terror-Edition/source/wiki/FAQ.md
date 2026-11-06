# ❓ FAQ — Preguntas Frecuentes

## 1. ¿El traductor causa lag o tirones en el juego al tener tantos miles de palabras?
**No.** El motor está altamente optimizado bajo estándares **Ultimate-Tier (v7.3.0)**. Combina un **Motor de Búsqueda Token-Bucket** (que precarga buckets y reduce las búsquedas lineales) con una caché LRU de **1024 registros**, optimizaciones GC-friendly de memoria estática y carga asíncrona de base de datos. Las traducciones se completan en microsegundos (<0.05ms) sin causar caídas de FPS ni tirones en hilos principales de Lua 5.0, ahora con inmunidad completa ante fallos de inicio.

## 2. ¿Qué idiomas soporta la versión v7.3.0?
**Soporta de manera trilingüe bidireccional Español, Inglés y Chino.** Además, incluye un Mega-Corpus ultra expansivo de 23 lotes temáticos con más de 8,700 entradas especializadas de World of Warcraft, TBC, HSK levels 1-5, jerga de juego, profesiones, consumibles, campos de batalla, expansiones de vocabulario, soporte de Turtle WoW, mecánicas Hardcore, mitigación de estilo Tarzán y modismos de chat.

## 3. ¿Cómo funciona el Modo Bilingüe (Bilingual Mode)?
El Modo Bilingüe permite mostrar simultáneamente en tu chat tanto el texto traducido como el mensaje original en un formato compacto y legible. Esto es de gran ayuda para aprender idiomas, depurar traducciones o entender frases coloquiales muy complejas.

## 4. ¿Qué es la pre-compilación de diccionarios (/tr compile)?
Es una característica de optimización extrema en la que el traductor pre-compila y estructura toda su base de datos léxica directamente en `pfUI_cache`. De este modo, la próxima vez que inicies el juego, los diccionarios se cargan instantáneamente en memoria en microsegundos sin necesidad de realizar el parsing inicial de texto plano de la base de datos de strings planos, eliminando el micro-stutter de carga de interfaz.

## 5. ¿Por qué el traductor a veces no traduce frases de chat y muestra el original?
Esto se debe al **Filtro de Ratio de Coherencia (CTR)**. Puedes configurar el umbral CTR en el panel de pfUI o dejarlo en `0.00` (desactivado). Para idiomas occidentales, si una frase no se puede traducir en su mayoría (menos del 40%), se descarta. Sin embargo, para Chino, el motor opera en un modo *best effort* agresivo priorizando siempre mostrar la mayor cantidad de información traducible posible.

## 6. ¿Qué hacen el Micro-stemmer y el Fuzzy Matcher (Levenshtein)?
*   **Micro-stemmer**: Reduce las palabras a su raíz morfológica básica (ej. quitando "-s", "-es", "-ing") para poder encontrar coincidencias en el diccionario aunque la palabra esté en plural o conjugada, reduciendo la redundancia de datos.
*   **Fuzzy Matcher**: Si falla la búsqueda exacta, calcula la distancia Levenshtein (menor o igual a 2 cambios) para emparejar palabras que tengan errores tipográficos leves o pequeños typos, mejorando drásticamente el matching en chats de juego acelerados.

## 7. ¿El buzón de correo también se traduce?
**Sí.** La suite Legendary-Tier incluye interceptores para el buzón de correo. Traduce de forma transparente los títulos y el contenido de las cartas entrantes al visualizarlas. Puedes activarlo o desactivarlo directamente con el toggle "Translate Mailbox" en el panel gráfico.

## 8. ¿Por qué algunos mensajes aparecen con [TR] o [ZH]/[EN]/[ES]?
El tag `[TR]` indica que el mensaje ha sido traducido localmente. Con la opción de **Language Badge** activa, el tag cambiará dinámicamente mostrando el idioma de procedencia (ej. `[ZH]`, `[EN]`, `[ES]`). Puedes ocultar todos los tags activando el **Silent Mode** en `/pfui` -> **Translator**.

## 9. ¿Por qué desaparecen las flechas o textos de misiones en AddOns externos como QuestVoice?
Con la introducción de soporte dinámico de fuentes asiáticas (`ZYHei`) vía `WoWTranslate.dll` (v7.3.1+), los AddOns externos que capturan la fuente por defecto (`pfUI.font_default`) *antes* de que pfUI complete su ciclo de carga pueden desincronizarse y colapsar al intentar renderizar texto chino. Para solucionar esto, actualiza tus AddOns externos (como **QuestVoice v1.0.1+**) que ya incorporan recargas dinámicas de fuentes y protecciones anti-nil.

---
© 2026 **DarckRovert** — El Séquito del Terror.
*Soporte Técnico Ultimate-Tier.*
