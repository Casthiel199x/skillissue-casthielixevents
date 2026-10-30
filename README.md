# SKILL ISSUE Event Series — V14 Foundation

Reconstrucción modular para continuar desarrollando sin seguir apilando parches. **No es una versión de producción probada**. Se ha comprobado sintaxis JS y estructura de archivos, pero no se ha ejecutado contra un proyecto Supabase real.

## Instalación segura

1. **No borres ni modifiques el Supabase antiguo**. Crea un proyecto nuevo de pruebas.
2. En el SQL Editor del nuevo proyecto ejecuta `database/schema.sql` completo. Está diseñado para un proyecto nuevo, no para migrar V13.
3. En Supabase Authentication crea un usuario con email y contraseña.
4. En SQL Editor ejecuta `insert into public.si_admins(email) values('TU_EMAIL_REAL');` sustituyendo por el email de ese usuario.
5. En `skill_issue_config.js` introduce la **Project URL** y la clave **publishable/anon** del proyecto nuevo. Nunca pegues una clave `service_role`.
6. Sube todos los archivos y carpetas del ZIP a un repositorio de pruebas de GitHub Pages (conserva las rutas). También puedes probar con un servidor local como `python -m http.server 8080`.
7. Abre `index.html`, inicia sesión, crea evento, guárdalo, publícalo, añade participantes y pruebas. Abre `skill_issue_live.html` en otra ventana.

## Arquitectura

- `js/core.js`: cliente Supabase REST, login, estado compartido, utilidades y cálculo de clasificación.
- `js/admin.js`: administrador modular.
- `js/live.js`: público, escenas, cuenta atrás y reacciones.
- `js/vote.js`: votos por código.
- `database/schema.sql`: esquema nuevo con RPC y controles de acceso; no expone directamente las tablas.

## Limitaciones deliberadas de esta base

- No incluye importación automática de los datos de V13 ni exportación de copias; conservar el Supabase antiguo.
- Realtime utiliza **polling cada 2 segundos** en esta versión; no hay suscripción WebSocket todavía.
- Los códigos de votación se muestran una sola vez; cópialos antes de salir de la pantalla.
- Los resultados de las pruebas de posiciones/manuales se introducen por administrador; no hay cronómetro automático de carrera.
- No se ha realizado una prueba end-to-end con Supabase real. Probar primero con datos ficticios.
- Reacciones sin enfriamiento por petición del organizador: pueden generar carga y costes; hay que implantar límites de infraestructura antes de un evento grande.
- Por ahora no hay migración de Halloween ni plantillas preconfiguradas; la estructura sí admite pruebas ilimitadas.

## Plan para la siguiente iteración

Pruebas reales, correcciones de permisos y de sincronización, plantillas, vista previa y estado de votación más detallado, importación segura de datos antiguos, historial y registro de cambios.


## V14.1 — puntos y publicación
- **Instalación nueva**: ejecutar `database/schema.sql` (incluye V14.1).
- **Proyecto V14 existente**: ejecutar únicamente `database/v14_1_migration.sql`. NO ejecutar schema.sql de nuevo.
- Configura la tabla de puntos en Eventos (p. ej. `10,8,6,5,4,3,2,2,2,2`).
- En pruebas de posiciones, el servidor calcula puntos al guardar; el campo Puntos es solo previsualización y no decide la puntuación final.
- Los resultados de pruebas nuevas son **borradores**; pulsa Publicar resultados para mostrarlos a espectadores.
- Si se publicó un resultado por error, vuelve a borrador, corrige y vuelve a publicar.
- La sincronización sigue usando polling cada 2 segundos. Comprueba que administrador y espectadores apuntan al MISMO proyecto Supabase y que el evento está activado.
- **Empates**: al publicar una prueba por posiciones, los puntos de las plazas empatadas se promedian y redondean a enteros.
- **Limitación**: no se ha probado contra Supabase real; prueba en un proyecto de desarrollo antes de publicar.
