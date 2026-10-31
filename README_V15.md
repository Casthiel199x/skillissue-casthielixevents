# SKILL ISSUE V15 — Perfiles de jugadores

## Qué incluye
- Perfiles persistentes vinculados a participantes mediante `profile_id`, con datos de personaje y estadísticas de pruebas publicadas.
- Ventana de ficha desde la clasificación pública, sin abandonar el directo.
- Editor manual de ficha en Participantes.
- Importación **experimental** desde Lodestone mediante Supabase Edge Function (depende de la disponibilidad y estructura HTML de Lodestone; no hay API oficial de perfiles garantizada).
- Reacciones concentradas en el centro inferior, con controles centrados.
- Se mantienen los módulos existentes de puntuaciones, eventos y votaciones.

## Instalar
1. Haz copia de seguridad de tu proyecto y base de datos.
2. Ejecuta `database/v15_profiles_migration.sql` en Supabase SQL Editor. Debes tener V14.3 y la columna `scoring` instaladas.
3. Sube a GitHub los archivos del ZIP **conservando tu `skill_issue_config.js` actual**.
4. Prueba la ficha manual: Participantes > Ficha > Guardar ficha; después abre la página pública y pulsa el nombre del jugador.
5. **Opcional**, para el botón «Importar desde Lodestone»: instala Supabase CLI, ejecuta `supabase functions deploy lodestone-profile` desde la raíz del proyecto, con el proyecto enlazado. La función exige un usuario autenticado que sea administrador. La importación es tentativa; si falla, usa el editor manual.

## Limitaciones y seguridad
- No se verifica la propiedad del personaje; `verified` permanece falso.
- Los retratos solo se aceptan desde dominios oficiales de imágenes de FFXIV.
- No se consulta información privada ni se prometen jobs, logros o equipo que Lodestone no proporcione.
- Los perfiles son persistentes, pero los participantes ya existentes requieren vinculación manual; no se deduplican automáticamente por nombre.
- Para actualizar los datos del personaje, vuelve a importar manualmente.
- Los datos de historial cuentan pruebas publicadas, no victorias globales de torneo.
- Esta versión no ha sido probada contra tu instancia de Supabase ni contra Lodestone en producción.
