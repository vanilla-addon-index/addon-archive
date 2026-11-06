# Contribución al Ecosistema Séquito

Gracias por tu interés en mejorar el Traductor Global. Para mantener el estándar **Diamond-Tier**, sigue estas directrices:

## Protocolos Técnicos
1. **Lua 5.0**: Se prohíbe el uso de sintaxis posterior a Vanilla WoW (ej. Operador `#`, `math.huge`, `string.gmatch`).
2. **Sin Placeholders**: Toda sugerencia de código debe estar completa y probada.
3. **Diccionario**: Para añadir términos, edita directamente `modules/translator_dict.lua` usando la función `add(es, en, zh)` siguiendo el formato trilingue de las categorías existentes. No existe una API de escritura en tiempo de ejecución.

## Proceso de Pull Request
- Asegúrate de actualizar el `CHANGELOG.md`.
- No toques la versión sin aprobación directa de **DarckRovert**.
- Documenta cualquier nuevo término añadido al diccionario en la sección correspondiente.

## Estilo de Código
- Sé directo y técnico en los comentarios.
- Mantén la arquitectura de hooks nuclear sin efectos secundarios.

---
Misión: Erradicar la mediocridad.