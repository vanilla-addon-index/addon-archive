# 🏰 Wiki: Arquitectura 'Legendary Tier' — pfUI [v7.3.1] (Translator v7.3.1)

Estructura modular del ecosistema **El Séquito del Terror** mantenido por **DarckRovert**.

---

## 🌐 Jerarquía de Carga (Boot Sequence)

El AddOn inicia mediante `init/modules.xml` con los siguientes puntos críticos de inyección:

1.  **Lexical Engine (`translator_dict.lua`)**: Carga inicial y estructuración en memoria de las categorías base. Utiliza carga diferida (Lazy Loading) para evitar picos de uso de CPU durante el inicio de la sesión del juego.
2.  **Colosal Database (`translator_dict_db.lua`)**: Inyecta una base de datos trilingüe masiva estructurada en 21 lotes temáticos (añadiendo los lotes de expansión v16 Giga Dictionary, v17 Adiciones de la Comunidad, v18 Mitigación de estilo Tarzán y v19 Mitigación Tarzán Avanzada y Modismos de Chat) comprimida por delimitadores `"|"`. Soporta pre-compilación binaria guardada en caché para omitir el parsing del texto plano y cargar instantáneamente.
3.  **Core Translator (`translator.lua`)**: Intercepta de forma asíncrona la entrada y salida de chat. Implementa:
    *   **Detección de Idioma Dinámica por Votación**: Tokeniza el mensaje en tiempo real para contar votos de coincidencia directa en los diccionarios (`es_en_words` y `en_es_words`) para palabras de longitud >= 3, erradicando el estado `unknown` para frases y modismos comunes cortos de WoW.
    *   **Motor Token-Bucket** para filtrado Greedy de complejidad $O(K)$.
    *   **Aislamiento Sintáctico y de Enlaces** para proteger la interactividad nativa de WoW.
    *   **Micro-stemmer** y **Levenshtein Fuzzy Matcher** para resolver variaciones y errores ortográficos.
    *   **Bilingual Rendering** y **Language Badges** para formatear el renderizado final.
4.  **Async DLL Bridge (Google Translate)**: Intercepción asíncrona de `UnitXP` que escala el procesamiento del idioma Chino (`zh`) a un componente en C++ (`WoWTranslate.dll`), obteniendo contexto completo de oraciones vía red sin congelar el cliente (Zero-Lag).
5.  **Mailbox & WIM Bridge**: Interceptores especializados sobre el buzón de correo (Mail Frame) y las ventanas de mensajería instantánea WIM para inyectar traducciones sin latencia.
6.  **GUI Integration (`gui.lua`)**: Panel integrado en las opciones de pfUI con 13 nuevos controles gráficos interactivos.

---

## 📊 Diagrama de Flujo: Traductor Multilingüe v7.3.1

```mermaid
graph TD
    A[Mensaje de Chat Event / Mail / WIM] --> B{Filtro de Canal / Ignorados}
    B -- Permitido --> C[Aislamiento del Mensaje Real]
    B -- Denegado / Ignorado --> Z[Render Estándar]
    C --> D["Extraer Prefijo y Cuerpo (Body)"]
    D --> E{Memoria de Idioma del Jugador}
    E -- Miss --> F[Detección de Idioma Heurística]
    E -- Hit --> G["Consultar Caché LRU (1024 registros)"]
    F --> G
    G -- Cache Hit --> H[Procesar Renderizado Final]
    G -- Cache Miss --> I[Normalización de Puntuación]
    I --> J[Micro-Stemmer Root Reduction]
    J --> K["Selector de Diccionario (Target Lang)"]
    K --> L["Motor Token-Bucket candidates"]
    L --> M["Greedy Matcher (Prioridad por longitud)"]
    M -- Miss --> N[Levenshtein Distance Fuzzy Matcher <= 2]
    M -- Hit --> O[Validación de Coherencia CTR]
    N -- Hit --> O
    N -- Miss --> P[Mantener Texto Original]
    O -- Aprobado --> Q[Actualizar LRU + Guardar en Memoria de Jugador]
    O -- Rechazado --> P
    O -- Aprobado --> DLL{¿Es Chino y hay DLL?}
    DLL -- Sí --> DLLQuery[Consulta Asíncrona a Google Translate]
    DLLQuery -- Timeout/Error --> P
    DLLQuery -- Éxito --> Q
    DLL -- No --> Q
    Q --> H
    P --> H
    H --> R{¿Modo Bilingüe Activo?}
    R -- Sí --> S[Ensamblar Original + Traducción]
    R -- No --> T[Ensamblar Solo Traducción]
    S --> U{¿Badge Activo?}
    T --> U
    U -- Sí --> V[Prefijar [ZH]/[EN]/[ES] según origen]
    U -- No --> W[Prefijar [TR] si no es Silent Mode]
    V --> X[Renderizar en Frame Destino]
    W --> X
```

---

## 🔐 Diseño de Seguridad y Optimización

### 1. Motor de Compilación de Diccionarios
A partir de la versión v7.0.0, el traductor incluye `/tr compile`. Esto toma todo el corpus procesado e indexado de palabras y frases y lo vuelca directamente en `pfUI_cache.translator_compiled`. Al recargar el juego o iniciar sesión, el AddOn detecta este caché binario precargado y lo mapea instantáneamente en memoria en microsegundos, omitiendo todo el bucle de parsing e indexación en cadena de strings planos de las bases de datos.

### 2. Aislamiento Sintáctico y de Enlaces
El motor utiliza un sistema doble:
1.  **Aislamiento Sintáctico**: Evita procesar la línea completa del chat. Encuentra el enlace del jugador (`|Hplayer:...`) y el delimitador `: ` para separar los canales y el nombre de la conversación propiamente dicha.
2.  **Encapsulado de Enlaces**: Un sistema regex detecta patrones `|H.-|h.-|h` y los reemplaza temporalmente con tokens protegidos `\127L[ID]\127` antes de traducir, garantizando que sigan siendo cliqueables e interactivos al finalizar el reensamblaje.

### 3. Normalizador Morfológico (Micro-Stemmer)
Para idiomas occidentales (ES/EN), el micro-stemmer reduce las palabras a su raíz morfológica común (ej. quitando sufijos plurales como "-s", "-es" o sufijos de verbos comunes como "-ing") antes de consultar los diccionarios. Esto reduce enormemente la redundancia del corpus del diccionario, permitiendo que una sola entrada cubra múltiples variaciones gramaticales.

### 4. Fuzzy Matcher de Distancia de Edición (Levenshtein)
Si el matching exacto falla, el sistema aplica una evaluación de distancia Levenshtein de coste acotado sobre las llaves del token-bucket activo. Permite tolerar errores tipográficos leves (distancia de edición menor o igual a 2) en palabras de longitud mayor a 4 caracteres, mejorando drásticamente el ratio de éxito en chats dinámicos.

### 5. Async DLL Bridge (Google Translate Proxy)
Para sortear las limitaciones del cliente Vanilla (1.12.1), el addon intercepta la función nativa de C++ `UnitXP()` sobrecargándola como un puente de mensajería IPC. Si el idioma detectado es chino y la DLL `WoWTranslate.dll` se encuentra inyectada, el motor descarta su resultado interno de estilo "Tarzán" y delega el mensaje a la DLL. La DLL realiza una petición HTTP asíncrona a los servidores de Google y, mediante un sistema de polling de alta frecuencia, devuelve el resultado al chat sin provocar microcortes en el juego. Adicionalmente, cuenta con purga inteligente en tiempo de inicialización de caché para re-procesar traducciones locales estancadas.

---
© 2026 **DarckRovert** — El Séquito del Terror.
*Soberanía Técnica Legendary-Tier Consolidada.*
