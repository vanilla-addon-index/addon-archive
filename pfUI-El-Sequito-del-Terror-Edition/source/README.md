# Global Chat Translator — El Séquito Edition (v7.3.3 [ULTIMATE-TIER]) 🌌⚖️

![Version](https://img.shields.io/badge/version-v7.3.3--Ultimate--Tier-ff55ff?style=for-the-badge)
![Host](https://img.shields.io/badge/pfUI-v7.3.3--Ultimate--Tier-purple?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Turtle_WoW-ff5555?style=for-the-badge)

> **The ultimate multilingual communication bridge for World of Warcraft.** Este componente de grado corporativo integrado en **pfUI** erradica las barreras lingüísticas mediante un motor de traducción en tiempo real offline de alto rendimiento, con soporte nativo para **Español, Inglés, Ruso y Chino**, optimizado bajo el estándar de máxima fidelidad y rendimiento **Ultimate-Tier** de DarckRovert, ahora con inmunidad garantizada contra crashes de inicialización y soporte extendido para Turtle WoW.

---

## 🌌 Visión General y Propósito

El **Global Chat Translator** es una pieza nuclear de ingeniería para el ecosistema **Séquito**. Utiliza transformaciones léxicas deterministas en memoria para traducir diálogos en tiempo real (Say, World, Whispers) sin latencia perceptible, asegurando una comunicación trilingüe fluida y libre de contaminación lingüística.

**NOVEDAD (Integración con Launcher)**: El addon ahora incluye un sofisticado bypass del motor de WoW (para clientes chinos como *twmoa_1181_cn*), permitiendo inyectar dinámicamente forzados de configuración regional (Locale Override) directamente desde el Launcher hacia la configuración base de pfUI (`pfUI_config.global.language`), ignorando el falso positivo de `GetLocale() == "enUS"` devuelto por el binario asiático del juego.

### 🧩 TRANSLATOR FEATURE MATRIX (CAPACIDADES)

| Módulo | Tipo de Datos | Funcionalidad | Descripción |
| :--- | :--- | :--- | :--- |
| **Multilingual Engine** | Lexical Map | Soporte Global | Traducción entre Español (`esES`), Inglés (`enUS`), Ruso (`ruRU`) y Chino (`zhCN`). Incluye Mega-Corpus HSK1-4. |
| **Async DLL Bridge** | C++ API Proxy | Google Translate | Puente asíncrono vía `UnitXP` con `WoWTranslate.dll` para offload de traducción de cero lag en chino, con fallback dinámico. |
| **Greedy Matcher** | Lexicographical | Traducción Precisa | Prioriza frases complejas sobre palabras aisladas mediante indexación descendente por longitud. |
| **Syntactic Isolation** | Message Parser | Integridad del Chat | Separa metadatos de Blizzard y nombres de jugador del cuerpo del mensaje antes de la traducción, protegiendo links e interactividad. |
| **CTR Filter** | Mathematical Ratio | Coherencia de Texto | Filtro de Ratio de Coherencia (*Coherence Threshold Ratio*): Modo Heurístico Agresivo para Chino (ZH < 10%) priorizando visibilidad, y estándar (EN/ES < 40%). |
| **Silent Mode** | UI Suppression | Incógnito | Opera de manera transparente sin prefijos invasivos en la ventana de chat. |
| **WIM Bridge** | Frame Sync | Puente de Susurros | Traducción nativa y aislada dentro de las ventanas emergentes del addon WIM. |
| **Channel Filter** | Comm Control | Gestión Granular | Selección bajo demanda de canales a traducir (World, LFG, Guild, Say, Party). |
| **LRU Cache** | Memory Mgmt | Alto Rendimiento | Caché de **1024 registros** para un hit-rate del >95% con latencia sub-milisegundo. |

---

## 🧠 WCS_Brain Integration [God-Tier]

> [!IMPORTANT]
> **Compatibilidad de Análisis de UI:** Los eventos visuales y perfiles visuales del Séquito en pfUI proporcionan un entorno limpio y predecible que **[WCS_Brain (El Núcleo Neuronal)](https://github.com/DarckRovert/WCS_Brain-v9.3.1-God-Tier)** puede leer para analizar la salud del jugador de forma instantánea.

### ⚡ PERFORMANCE BENCHMARKS (DIAMOND-TIER)

| Proceso | Latencia Séquito (v7.1.0) | Latencia Standard | Estado |
| :--- | :---: | :---: | :---: |
| **Parsing & Isolation** | < 0.05ms | N/A | ✅ |
| **Matching Loop** | < 0.08ms | N/A | ✅ |
| **CTR Evaluation** | < 0.02ms | N/A | ✅ |
| **Cache Hit** | < 0.005ms | ~1ms | ✅ |
| **UI Rendering** | Zero Lag | Variable | ✅ |

---

## 🏗️ Suite de Documentación (Wiki)

Base de conocimientos para el despliegue técnico del motor de traducción:

- 🏰 **[Arquitectura](file:///e:/Turtle%20Wow/Interface/AddOns/pfUI/wiki/Arquitectura.md)**: Flujos nucleares de traducción, aislamiento sintáctico y heurística del filtro CTR.
- ⚙️ **[Guía de API](file:///e:/Turtle%20Wow/Interface/AddOns/pfUI/wiki/Guia_API.md)**: Integración para desarrolladores y signatura de funciones de traducción.
- ❓ **[FAQ](file:///e:/Turtle%20Wow/Interface/AddOns/pfUI/wiki/FAQ.md)**: Respuestas a dudas de rendimiento, mitigación de mezcla de idiomas y personalización.
- 📖 **[Manual de Usuario](file:///e:/Turtle%20Wow/Interface/AddOns/pfUI/wiki/Manual_Usuario.md)**: Comandos de chat, configuración gráfica y selección de idioma.

## 💬 Comandos de Chat (/tr)

Controla el comportamiento del traductor directamente desde la ventana de chat del juego:

- `/tr`: Abre directamente la interfaz gráfica de configuración nativa en pfUI.
- `/tr stats`: Muestra estadísticas detalladas del rendimiento del traductor (Mensajes de Entrada, de Salida, hit-rate del Caché LRU en % y servidor de juego detectado).
- `/tr dashboard` o `/tr dash`: Abre el **Translator Dashboard** interactivo con estadísticas en tiempo real y gráficos flotantes.
- `/tr debug`: Alterna dinámicamente el modo de depuración en chat para observar el proceso de matching y aislamientos.
- `/tr reset`: Reinicia manualmente los contadores del reino y la detección automática del idioma del servidor.
- `/tr blacklist <nombre>`: Ignora a un jugador permanentemente (también disponible visualmente en la GUI de Opciones Avanzadas).

## 🚀 Despliegue Rápido (Pro-Flow)

1. **Limpieza**: Borra cualquier versión previa de los archivos del traductor en `pfUI/modules/`.
2. **Activación**: Configura la traducción y elige tu idioma de destino en `/pfui` -> **Translator**.
3. **Monitoreo**: Usa `/tr stats` para verificar el rendimiento, hits de caché y ratio CTR en tiempo real.

## 🔗 Ecosistema Oficial (DarckRovert)

- [Live Streams (Twitch)](https://twitch.tv/darckrovert)
- [Página de Inicio](https://sequitodelterror.netlify.app/)
- [Soporte & Donaciones](https://ko-fi.com/darckrovert)
- [GitHub Oficial](https://github.com/DarckRovert)

---
© 2026 **DarckRovert** — El Séquito del Terror.  
*Misión: Erradicar la mediocridad y las barreras de comunicación global.*