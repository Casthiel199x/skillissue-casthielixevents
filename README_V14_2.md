# SKILL ISSUE Event Series V14.2

## Instalación
1. Haz una copia de seguridad de Supabase y de tu carpeta GitHub actual.
2. Ejecuta SOLO `database/v14_2_migration.sql` en SQL Editor (requiere V14.1 ya instalada).
3. Sube los archivos del ZIP a GitHub Pages, conservando tu `skill_issue_config.js` configurado.
4. Recarga con Ctrl+F5.

## Cambios
- Finalizar evento / Reabrir evento desde el editor de eventos. El evento finalizado sigue visible en la página pública como histórico final, pero **no aparece EN DIRECTO**. Puede reabrirse para editar.
- Al finalizar, las votaciones abiertas se cierran. **Antes de finalizar, cierra cada votación con «Cerrar y puntuar» para contar los votos**. No se calcula automáticamente al finalizar.
- Resultados por prueba (solo publicados) en la página pública, con posiciones y puntos.
- Una prueba recién publicada aparece destacada durante unos 9 segundos mientras el navegador está abierto y detecta el cambio; después vuelve a la escena configurada. No persiste el temporizador entre recargas.
- Botón «Copiar para Discord» con la clasificación general.
- Los datos y el SQL de V14.1 se conservan.

## Pruebas recomendadas
1. Crear evento, dos pruebas y participantes.
2. Asignar resultados y publicar una prueba; confirmar que se ve en espectadores.
3. Publicar otra prueba y comprobar el destacado temporal.
4. Finalizar el evento y verificar estado FINALIZADO, podio y bloqueo de edición.
5. Reabrirlo y verificar que puede editarse de nuevo.

No probado contra tu Supabase real. El estado «publicado» sigue representando el evento mostrado públicamente, aunque esté finalizado; el estado «en directo» es independiente.
