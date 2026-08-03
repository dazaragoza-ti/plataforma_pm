# Diseño de base de datos — Kanban PM

Este documento explica el **por qué** detrás de `kanban_schema.sql`, no el qué
(el propio archivo `.sql` ya está comentado línea por línea). Está escrito
para dos audiencias: quien evalúe si este diseño es razonable antes de
construir el backend real, y quien lo herede después y necesite entender por
qué una regla vive en un trigger y no en el cliente, o por qué una tabla
existe cuando "parecía que con una columna bastaba".

Motor objetivo: **PostgreSQL 14+**. La lógica de negocio es portable a
cualquier motor relacional serio (SQL Server, MySQL 8, Oracle); lo que cambia
es la sintaxis de funciones/triggers, no el modelo.

---

## 1. Contexto: de dónde sale este modelo

Este esquema **no es un diseño de pizarrón** — es el resultado de aterrizar
en tablas un modelo de dominio que ya existe y funciona, hoy respaldado por
`InMemoryKanbanRepository`/`InMemoryWorkspaceRepository`
(`lib/features/kanban_pm/data/*.dart`), y de una auditoría exhaustiva de ese
mismo módulo a lo largo de más de veinte rondas de revisión de bugs. Varias
de las restricciones de este esquema (secciones 15.8–15.10 del `.sql`)
existen exclusivamente porque un bug real se coló en la aplicación por no
tener ese invariante garantizado en un solo lugar — se explican una por una
en la sección 5.

La consecuencia práctica: el contrato `KanbanRepository`
(`data/kanban_repository.dart`) ya está diseñado para que, el día que exista
un backend real, baste con escribir `ApiKanbanRepository implements
KanbanRepository` sin tocar la capa de presentación. Este esquema es el
"otro lado" de ese contrato — la base de datos que esa implementación real
usaría.

---

## 2. Por qué relacional y no un documento (NoSQL)

El dominio tiene tres características que un modelo relacional resuelve
mejor que un documento por tarea:

1. **Relaciones N:M reales y consultables en ambas direcciones.** Una tarea
   tiene varias etiquetas y varios miembros; una etiqueta/miembro está en
   varias tareas. Un documento por tarea (con arrays de ids embebidos)
   resuelve "dame las etiquetas de esta tarea" gratis, pero "dame todas las
   tareas con la etiqueta X" o "cuántas tareas activas tiene este miembro"
   exige un índice invertido o un `$lookup` en cada consulta — exactamente lo
   que un `JOIN` con clave foránea ya hace de forma nativa.

2. **Invariantes que cruzan varias entidades a la vez.** El límite de WIP de
   una columna, "no dejar el workspace sin nadie con acceso", "no crear un
   ciclo de dependencias" — ninguno de estos se puede expresar como una regla
   de validación de un solo documento; todos necesitan ver el estado de
   *otras* filas en el mismo instante de la escritura. Un motor relacional
   con triggers y transacciones ACID hace esto de forma atómica y sin
   condiciones de carrera; replicarlo a mano contra una base de documentos
   exige tu propia capa de bloqueos optimistas.

3. **El árbol de subtareas necesita recursión de profundidad arbitraria.**
   `Actividad.subActividades` se delega sin límite de niveles. `WITH
   RECURSIVE` (usado en 4 lugares del esquema: progreso, auto-pausa,
   ruta de dependencias) es la herramienta relacional exacta para esto; en un
   documento tocaría, o limitar la profundidad de antemano, o desnormalizar
   el árbol completo en cada lectura.

Ninguna de las tres es exótica, pero juntas son la razón por la que este
dominio encaja mejor en tablas que en documentos — no es una preferencia
estilística.

---

## 3. Decisiones de modelado y su razón

### 3.1 `workspace_id` en (casi) cada tabla, no un esquema por cliente

Cada área de trabajo es un tablero Kanban independiente, pero **viven en las
mismas tablas**, distinguidas por `workspace_id` — no un `CREATE SCHEMA` por
cliente ni bases de datos separadas. Se eligió así porque:

- El número de workspaces por instalación es potencialmente grande y crece
  con el uso normal de la app (cada usuario puede crear varios) — un patrón
  de "un schema por tenant" está pensado para decenas o cientos de tenants
  administrados, no para que cualquier persona cree uno nuevo con un clic.
- Todas las consultas cross-workspace que la app ya necesita hoy
  (`listarWorkspacesDe`, el directorio global de `usuario`, potencialmente
  reportes futuros entre áreas) son triviales con `workspace_id` como
  columna y prohibitivamente caras de expresar contra N schemas distintos.
- El aislamiento entre áreas no depende de la partición física sino de que
  **todas las consultas de la API real filtren por `workspace_id`** (o, más
  adelante, de Row-Level Security de Postgres — ver sección 6).

### 3.2 `TareaEstatus` como texto libre con llave compuesta, no un `ENUM`

`kanban_columna` usa `(workspace_id, estatus_id)` como llave primaria, con
`estatus_id` un `VARCHAR` (no un `ENUM` de Postgres ni un `CHECK IN (...)`
sobre valores fijos). La razón es que **el dominio ya dejó de ser un enum
cerrado**: `TareaEstatus` en Dart pasó de un `enum` de 5 valores a una clase
con identidad por `id` (ver `domain/entities/tarea_estatus.dart`) precisamente
para soportar columnas creadas por el usuario en tiempo de ejecución
(`TareaEstatus.personalizado`). Un `ENUM` de Postgres es fijo por definición
(agregar un valor exige `ALTER TYPE ... ADD VALUE`, una migración); modelar
esto con texto libre + FK compuesta dijo "cualquier fila de `kanban_columna`
es un estatus válido para ese workspace" sin tener que tocar el esquema cada
vez que alguien crea una lista nueva.

Las 5 columnas "estándar" (`tareas`, `proceso`, `pausa`, `terminado`,
`revisado`) no tienen ningún trato especial a nivel de tabla — son
simplemente las filas que `sp_crear_workspace` siembra siempre. Los pocos
lugares que sí necesitan saber "esto es exactamente proceso/terminado/etc."
(auto-pausa, estampado de fechas reales) lo hacen comparando el texto
literal, igual que Dart compara `TareaEstatus.proceso` por identidad.

### 3.3 Árbol de actividades vía auto-referencia, no columnas de profundidad fija

`tarea_actividad.padre_id` apunta a otra fila de la misma tabla. La
alternativa (columnas `actividad_nivel_1_id`, `nivel_2_id`, etc., o un JSON
anidado) se descartó porque el propio dominio declara explícitamente "sin
límite de profundidad" (`Actividad.subActividades`, delegación en cadena) —
cualquier profundidad fija tarde o temprano se queda corta. `WITH RECURSIVE`
paga ese precio con una sola definición de consulta reutilizada en:
progreso (`fn_progreso_tarea`), bloqueo por subtarea
(`fn_recalcular_bloqueo_subtareas`) y, si se necesitara, cualquier reporte
futuro sobre el árbol completo.

### 3.4 Identidad global (`usuario`) separada del catálogo por workspace (`miembro`)

Esta es la distinción más importante del modelo y la que menos obvia parece
a primera vista. `miembro` es "esta persona, tal como existe dentro de ESTE
tablero" (su nombre y color ahí pueden diferir de otro workspace, e incluso
puede no estar ligada a nadie del directorio global). `usuario` es "esta
persona, sin importar en cuántas áreas participe". La razón de separarlos:

- Sin esta separación, agregar a alguien de otro departamento a una sola
  actividad puntual (el caso de "invitado", ver 3.5) crearía un registro sin
  ninguna forma de reconocerlo después como la misma persona en su propio
  workspace — cada área tendría su propia isla de "Juan Pérez" sin relación
  entre sí.
- Con la separación, `miembro.usuario_id` es opcional (`ON DELETE SET
  NULL`): un miembro puede existir *solo* en un workspace (el caso de hoy,
  sin login real) sin necesitar nunca una fila en `usuario`.

### 3.5 Rol por membresía (`miembro.rol`), no un rol global de usuario

`rol` (`dueño` / `miembro` / `invitado`) vive en `miembro`, no en `usuario`,
porque el nivel de participación es **por workspace**, no un atributo de la
persona: la misma persona puede ser dueña de su propia área e invitada en la
de alguien más al mismo tiempo. El caso concreto que motivó esto (documentado
en la sección 7.1 del `.sql`): TI necesita que alguien de Calidad resuelva
una sola actividad, así que se le agrega como `invitado` — puede trabajar en
lo suyo y ver el tablero, pero no administra el catálogo compartido
(etiquetas/columnas/miembros) de un área a la que no pertenece de verdad
(`trg_bloquear_catalogo_invitado`).

### 3.6 Etiquetas personales compartibles (`usuario_etiqueta`)

Esta tabla (y sus triggers/función de propagación, sección 7.1 y 15.6-15.7
del `.sql`) es una **extensión propuesta**, no algo que exista todavía en el
Dart de hoy — `TareaEtiqueta` en memoria es 100% local a un workspace, sin
concepto de "mi etiqueta personal". Se incluyó en el diseño porque es la
extensión natural una vez que existe `usuario` como identidad compartida: sin
ella, alguien que usa la misma etiqueta ("Urgente-Cliente X") en 5 áreas
distintas la recrea a mano 5 veces y las mantiene desincronizadas para
siempre. El diseño (crear/reutilizar + propagar solo a áreas donde el rol es
`dueño`/`miembro`, nunca `invitado`) se explica con detalle en el propio
`.sql`. Si el backend real no necesita esto todavía, la tabla y sus triggers
se pueden omitir sin afectar el resto del esquema — no hay ninguna FK
obligatoria hacia ella (`tarea_etiqueta.usuario_etiqueta_id` es `NULL`able).

### 3.7 Historial como bitácora append-only, escrita solo por triggers

`tarea_historial` no tiene ningún `UPDATE`/`DELETE` esperado, y ninguna capa
de la aplicación inserta ahí a mano — los triggers de la sección 15.4 lo
hacen solos al detectar cambios de estatus/prioridad/actividades. La razón:
un historial que la aplicación pudiera escribir directamente es, tarde o
temprano, un historial con un evento real que alguien olvidó registrar (un
`UPDATE` hecho por otra ruta de código, una migración de datos, un cliente
distinto) — moverlo a un trigger lo vuelve **imposible de saltarse**, sin
importar por dónde entre el cambio.

### 3.8 Fechas planeadas vs. reales, y por qué necesitan un trigger

`fecha_inicio`/`fecha_vencimiento` los edita la persona usuaria;
`fecha_inicio_real`/`fecha_fin_real` los sella el sistema solo, al entrar a
"proceso" y a un estatus cerrado respectivamente (`trg_estampar_fechas_
reales`). Esto no se puede dejar como "responsabilidad de la aplicación
acordarse de setear la fecha real cada vez que mueve una tarjeta" por la
misma razón que el historial: cualquier camino de escritura que lo olvide
(un import masivo, una migración, un futuro segundo cliente) deja el Gantt
comparando fechas planeadas contra un vacío. Ponerlo en un trigger lo hace
verdad para *cualquier* `UPDATE` de `estatus_id`, sin excepción.

Este trigger tiene además una **divergencia intencional** frente al Dart de
hoy, documentada con su propio comentario largo en el `.sql` (sección 15.2):
`InMemoryKanbanRepository` NO limpia `fechaFinReal` al reabrir una tarea (dejó
el valor del cierre anterior y en su lugar exige que cada consumidor revise
`tarea.cerrada` antes de confiar en el campo) — un rodeo razonable en un
repositorio en memoria, donde tocar cada consumidor es más barato que
añadir estado derivado. A nivel de base de datos sí conviene limpiarlo: así
`fecha_fin_real IS NOT NULL` significa, sin excepción, "sigue cerrada y esta
es su fecha de cierre vigente" — un único invariante que cualquier consulta
futura puede confiar ciegamente. Cuando exista un backend real, el cliente
Dart puede simplificarse para apoyarse en este invariante en vez de mantener
su propio rodeo.

### 3.9 `orden` como entero denso por columna, no un timestamp o un `LexoRank`

Reordenar tarjetas dentro de una columna (arrastrar-y-soltar) usa un entero
`orden` que se **renumera completo** (0..n-1) en cada movimiento
(`sp_mover_tarea`), no un timestamp de creación ni un esquema de rangos tipo
`LexoRank`/`fractional indexing`. Para el volumen esperado (decenas de
tarjetas por columna, no millones) renumerar es más simple de razonar y
depurar que mantener un espacio de claves fraccionario, al costo de un
`UPDATE` de varias filas por movimiento en vez de una sola — un cambio
razonable si el volumen creciera órdenes de magnitud.

### 3.10 Triggers para reglas de negocio críticas, no solo validación en el cliente

Esta es la decisión de arquitectura más importante del esquema y merece su
propia sección — ver la sección 5 completa.

---

## 4. Por qué estas tablas de catálogo y no otras alternativas

- **`prioridad_catalogo` como tabla, no `ENUM`.** Cuatro valores fijos
  (baja/media/alta/urgente) con un color asociado — un `ENUM` de Postgres
  modelaría los 4 valores pero no su color; guardarlo en una tabla evita
  duplicar el color hexadecimal en cada capa (SQL, Dart, cualquier futuro
  cliente) que necesite pintarlo.
- **`color_paleta_catalogo` como tabla de referencia, no una constante
  hardcodeada en cada capa.** Espeja `kColorPaletteEtiquetas` de
  `kanban_constants.dart` — el mismo argumento: un solo lugar de verdad para
  "estos son los colores que puede elegir un selector de color", consultable
  por cualquier cliente sin duplicar el arreglo.

---

## 5. Invariantes que la base de datos garantiza por sí sola (y el bug que cada uno cierra)

Esta lista es, a propósito, trazable a comportamiento real observado en la
aplicación — no reglas hipotéticas. Cada una tiene su trigger correspondiente
en la sección 15 del `.sql`:

| Invariante | Trigger | Qué pasaba sin él |
|---|---|---|
| Una columna con límite de WIP no puede recibir más tarjetas de las permitidas | `trg_validar_wip_tarea` (15.1) | El límite era puramente decorativo — se podían amontonar tarjetas sin límite en "Proceso" pese a mostrar el aviso rojo. |
| `fecha_inicio_real`/`fecha_fin_real` siempre reflejan el ciclo de vida vigente, sin importar cuántas veces se reabra/cierre la tarea | `trg_estampar_fechas_reales` (15.2) | Reabrir y volver a cerrar una tarea dejaba la fecha de cierre pegada en el primer cierre, distorsionando KPIs de cumplimiento y el Gantt. |
| Ninguna tarea puede terminar en una columna archivada (crear, mover, o vía auto-pausa/auto-reanudación) | `trg_prevenir_tarea_en_columna_archivada` (15.8) + el pre-chequeo dentro de `fn_recalcular_bloqueo_subtareas` (15.3) | Una tarjeta activa podía volverse invisible — sin aparecer en el tablero ni en "tarjetas archivadas" — con solo archivar una columna (incluida "Pausa") mientras algo la auto-movía ahí. |
| Un ciclo de dependencias (A depende de B que depende de A) no se puede crear | `trg_prevenir_dependencia_circular` (15.5) | El guard anti-ciclo del Gantt en Dart se evaluaba sobre listas ya filtradas por la vista activa; una tarea archivada o fuera del filtro visible podía cerrar el ciclo sin que nadie lo detectara. |
| No se puede archivar la última columna visible de un workspace | `trg_prevenir_archivar_ultima_columna` (15.9) | El tablero podía quedar sin ningún lugar donde soltar o crear tarjetas nuevas. |
| No se puede quitar a la última persona con acceso (`usuario_id` no nulo) de un workspace | `trg_prevenir_quitar_ultimo_acceso` (15.10) | El área seguía existiendo con todas sus tareas, pero quedaba inaccesible para siempre — ni siquiera quien la creó podía volver a verla en su selector. |
| Un `invitado` puede aplicar etiquetas ya existentes, pero no administrar el catálogo de un workspace ajeno | `trg_bloquear_catalogo_invitado` (15.7) | Sin esta separación de rol, agregar a alguien para una sola actividad le daba de facto control total sobre el catálogo compartido del área. |
| Ningún nombre de workspace/columna/tarea/etiqueta/miembro/plantilla puede quedar en blanco | `CHECK` de la sección 17 | Un nombre vacío es invisible/inseleccionable en cualquier lista o selector de la UI. |

La decisión de fondo detrás de esta tabla: **cada una de estas reglas ya
existía como validación en algún punto de la capa de presentación de
Dart** — y en más de un caso, existía en un punto pero no en otro camino
paralelo que llegaba al mismo dato (el motivo real de varios de los bugs
que la llevaron a descubrirse). Centralizarlas en la base de datos, en vez
de confiar en que cada futuro cliente (la app móvil, un panel de admin, un
script de importación) las reimplemente todas correctamente, es la única
forma de que un invariante de negocio sea **imposible de violar por
accidente**, sin importar cuántos clientes distintos terminen escribiendo
a la misma base.

---

## 6. Qué falta para producción (deliberadamente fuera de este esquema)

Este `.sql` modela el dominio, no toda la operación de un backend real. Fuera
de alcance a propósito:

- **Autenticación real.** `usuario_actual` en Dart es una sesión simulada
  (se cambia a mano desde el selector de áreas). Cuando exista login real,
  `usuario` se puebla desde ahí en vez de sembrarse a mano — el resto del
  modelo (membresías, catálogo personal) no cambia.
- **Row-Level Security (RLS).** Hoy el aislamiento entre workspaces depende
  de que cada consulta filtre por `workspace_id` a mano. Con autenticación
  real, envolver esto en políticas RLS de Postgres (`CREATE POLICY ... USING
  (workspace_id IN (SELECT workspace_id FROM miembro WHERE usuario_id =
  current_setting('app.usuario_actual_id')))`) lo vuelve imposible de
  saltarse por un bug de un cliente, en vez de solo "improbable".
- **Migraciones versionadas.** Este archivo es un snapshot completo (`CREATE
  TABLE`), no una cadena de migraciones incrementales — la herramienta real
  (Flyway, sqlx, Prisma Migrate, lo que use el backend) debería partirlo en
  pasos versionados antes de aplicarlo contra una base con datos reales.
- **Particionado/archivado físico.** `tarea.archivada`/`kanban_columna.
  archivada` son *soft delete* lógico (para "Deshacer" y recuperación) — no
  hay estrategia de partición ni de purga física para cuando el volumen de
  tareas archivadas crezca mucho; no hace falta hasta que el volumen real lo
  justifique.
- **Notificaciones/websockets.** El modelo de datos no incluye ninguna cola
  de eventos para tiempo real (p. ej. "alguien más movió esta tarjeta ahora
  mismo") — es una capa aparte sobre esta misma base, no una tabla más aquí.

---

## 7. Cómo se conecta esto con el código Dart de hoy

| Este esquema | Código Dart equivalente |
|---|---|
| Todo el `.sql` | `data/kanban_repository.dart` (el contrato), `data/in_memory_kanban_repository.dart` (la implementación de referencia que este esquema reemplazaría) |
| `workspace`, `kanban_columna` (siembra estándar) | `data/workspace_repository.dart`, `kColumnas` en `kanban_constants.dart` |
| `usuario`, `usuario_directorio` (fuera del `.sql`, es una tabla más) | `data/usuario_directorio.dart` |
| `tarea` + `tarea_actividad` + relaciones N:M | `domain/entities/tarea.dart`, `domain/entities/actividad.dart` |
| `tarea_historial` | `domain/entities/historial_evento.dart` |
| `tarea_plantilla` + sus 3 tablas de relación | `domain/entities/tarea_plantilla.dart` |

El día que se implemente `ApiKanbanRepository`, cada método de la interfaz
debería mapear 1:1 a una consulta o llamada a un procedimiento de este
esquema — es, literalmente, para lo que se diseñó.
