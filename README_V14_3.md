# SKILL ISSUE V14.3 — Corrección de eventos

## Cambios
- Añade botón Eliminar evento con doble confirmación y borrado en cascada.
- Si el evento eliminado estaba publicado, desvincula primero si_active para evitar errores de clave foránea.
- Permite finalizar un evento activo incluso si aún figura como borrador; conserva su historial y muestra ceremonia.
- Corrige la selección del administrador después de eliminar un evento.

## Instalación
1. Haz una copia de seguridad de Supabase y de tu GitHub actual.
2. Ejecuta database/v14_3_migration.sql en Supabase SQL Editor **después** de V14.2.
3. Sustituye index.html y js/admin.js en GitHub por los de este ZIP. No cambies tu configuración de Supabase.
4. Ctrl+F5. Prueba primero con un evento ficticio.

## Importante
Eliminar es irreversible y elimina las pruebas, jugadores, resultados y votos asociados. Finalizar conserva los datos. Si Supabase no ejecutó correctamente la migración, la operación mostrará un error; no afirmamos haberla probado contra tu proyecto.
