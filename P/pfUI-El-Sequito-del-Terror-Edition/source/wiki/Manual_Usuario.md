# 📖 Manual de Usuario (v7.3.1 [ULTIMATE-TIER])

Guía oficial para dominar el sistema de comunicación multilingüe de **El Séquito Edition**, ahora con inmunidad garantizada contra fallos de ejecución y traducción fluida humana.

---

## 1. Configuración Inicial
Accede al panel de control escribiendo `/pfui` y navegando a la pestaña **Translator** (Traductor).

### Opciones de Configuración (Expandidas)
*   **Enable Translator**: Activa o desactiva por completo el motor de traducción.
*   **Translate Incoming**: Habilita la traducción en tiempo real de los mensajes que recibes de otros jugadores.
*   **Translate Outgoing**: Traduce automáticamente los mensajes que tú escribes al idioma del servidor antes de enviarlos.
*   **Bilingual Mode**: Permite renderizar simultáneamente en chat el mensaje traducido y el original.
*   **Language Badge**: Prefija el idioma original (e.g., `[ZH]`, `[EN]`, `[ES]`) en el chat en lugar de un tag genérico.
*   **Silent Mode**: Si está activo, oculta los tags al final de los mensajes traducidos para un chat visualmente limpio.
*   **WIM Bridge**: Habilita la traducción transparente en las ventanas de susurros de WIM.
*   **Translate Mailbox**: Habilita la traducción automática de correos entrantes en el buzón.
*   **Enable Stemming**: Activa el normalizador morfológico para mejorar el matching de plurales y conjugaciones.
*   **Player Memory**: Recuerda el idioma de los jugadores para acelerar la heurística y ahorrar recursos.
*   **Sound Notification**: Emite una alerta auditiva discreta al recibir o procesar una traducción.
*   **Anti-Spam Filter**: Deduping automático para evitar spam traducido duplicado y redundante.
*   **Tag Color Selection**: Selector gráfico para personalizar el color del tag `[TR]` o de los badges.

---

## 2. Traducción Integral en el Juego
La versión **v7.3.1 (Ultimate-Tier)** integra de forma nativa la traducción en tiempo real de:
1.  **Facultades de Clase (Spells)**: Hechizos y habilidades principales de WoW y TBC.
2.  **Misiones (Quests)**: Nombres de misiones de Azeroth clásicos y personalizados de Turtle WoW.
3.  **Ítems y Equipamiento**: Armas, armaduras, consumibles de raid y materiales.
4.  **Atributos y Talentos (Specs)**: Estadísticas primarias, índices de golpe, golpe crítico, sp, ap y especializaciones.
5.  **Campos de Batalla (BGs & PvP)**: Objetivos, avisos de mapa, cementerios y rangos.
6.  **Profesiones e Interacciones**: Primarias, secundarias (incluyendo Supervivencia/Survival) y recetas.
7.  **Emotes de Chat**: Traducción contextual de acciones y emotes del juego.
8.  **Buzón de Correo (Mailbox)**: Traducción interactiva al leer tus correos en el juego.
9.  **Detección Dinámica de Idioma por Tokens**: Motor heurístico híbrido que tokeniza mensajes cortos en tiempo real y realiza un sistema de votación contra diccionarios para resolver la ambigüedad lingüística y la traducción de frases coloquiales cortas.

---

## 3. Comandos de Chat (/tr)
Controla el comportamiento del traductor directamente desde la ventana de chat del juego:

*   `/tr`: Abre directamente la pestaña de configuración del traductor en la interfaz gráfica de pfUI.
*   `/tr stats`: Muestra estadísticas detalladas del rendimiento (Mensajes procesados, hit-rate del Caché LRU en %, servidor detectado y top de palabras frecuentes).
*   `/tr debug`: Alterna dinámicamente el modo de depuración en chat para observar el proceso de matching y aislamientos. *Nota: Si la DLL de Google Translate (WoWTranslate) está inyectada y la conexión falla, este modo imprimirá el motivo exacto del error en el chat.*
*   `/tr quick`: Abre/cierra una práctica ventana interactiva flotante de traducción rápida manual.
*   `/tr panel`: Alterna la visibilidad de una pequeña barra indicadora de estado en tu pantalla.
*   `/tr history` (o `/tr hist`): Muestra el historial de las últimas 10 traducciones realizadas en tu sesión.
*   `/tr last`: Muestra únicamente la última traducción realizada con remitente e idioma de origen.
*   `/tr reset`: Reinicia manualmente los contadores del reino y la detección automática del idioma del servidor.
*   `/tr ignore Nombre`: Agrega a un jugador a la lista negra del traductor para ignorar sus mensajes.
*   `/tr unignore Nombre`: Remueve a un jugador de la lista negra del traductor.
*   `/tr addrule es|en|zh`: Añade en caliente una regla de traducción personalizada (ej: `/tr addrule gato|cat|猫`).
*   `/tr compile`: Compila los diccionarios cargados en un formato binario optimizado en caché para un inicio ultra rápido.

---

## 4. Gestión Granular de Canales
Puedes activar o desactivar selectivamente qué canales de chat deseas traducir en el panel gráfico:
*   **Decir (Say) / Emote**: Para interacción local en el mundo.
*   **Grupo (Party) / Banda (Raid) / Raid Warning**: Ideal para coordinar mazmorras y bandas internacionales.
*   **Hermandad (Guild) / Oficial (Officer)**: Comunicación con tus compañeros de hermandad.
*   **Mundo (World) / LFG / Comercio (Trade)**: Gestión del chat global masivo.
*   **Susurros (Whisper)**: Susurros directos bilaterales.

---
© 2026 **DarckRovert** — El Séquito del Terror.
*Soberanía del Usuario Ultimate-Tier.*
