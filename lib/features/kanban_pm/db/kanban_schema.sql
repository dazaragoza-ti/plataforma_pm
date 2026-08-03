-- ============================================================================
-- KANBAN PM — Estructura de base de datos
-- ============================================================================
-- Motor objetivo: PostgreSQL 14+ (usa gen_random_uuid()/now(), FILTER,
-- funciones PL/pgSQL, RAISE EXCEPTION, WITH RECURSIVE). Si el backend real
-- termina en otro motor la lógica es la misma; solo cambia la sintaxis de
-- funciones/procedimientos (T-SQL, PL/SQL, etc.) y algún tipo de dato.
--
-- Este archivo es un ESPEJO 1:1 del modelo hoy vivo en:
--   lib/features/kanban_pm/domain/entities/*.dart
--   lib/features/kanban_pm/data/kanban_repository.dart
--   lib/features/kanban_pm/data/workspace_repository.dart
--   lib/features/kanban_pm/data/usuario_directorio.dart
-- (hoy implementados en memoria vía InMemoryKanbanRepository /
-- InMemoryWorkspaceRepository / UsuarioDirectorio) — pensado para el día
-- que ese mismo contrato se respalde con un backend/API real, sin tocar la
-- capa de presentación (ver el comentario de diseño en kanban_repository.dart).
--
-- Login real: todavía no existe (`usuario_actual` en Dart es una sesión
-- simulada, cambiable a mano desde el selector de áreas). Cuando exista
-- autenticación de verdad, `usuario` pasa a poblarse desde ahí en vez de
-- sembrarse a mano, pero el resto del modelo (membresías, catálogo
-- personal de etiquetas) no cambia.
-- ============================================================================


-- ============================================================================
-- 1. CATÁLOGOS / LISTAS
-- ============================================================================

-- Espeja TareaPrioridadX (domain/entities/tarea_prioridad.dart): 4 valores
-- fijos con su color asociado. Se modela como tabla (no ENUM) para no
-- duplicar el color en cada capa que lo necesite.
CREATE TABLE prioridad_catalogo (
  id        VARCHAR(20) PRIMARY KEY,   -- 'baja' | 'media' | 'alta' | 'urgente'
  etiqueta  VARCHAR(30) NOT NULL,
  color_hex CHAR(7)     NOT NULL,
  orden     SMALLINT    NOT NULL
);

INSERT INTO prioridad_catalogo (id, etiqueta, color_hex, orden) VALUES
  ('baja',    'Baja',    '#22C55E', 1),
  ('media',   'Media',   '#2196F3', 2),
  ('alta',    'Alta',    '#F59E0B', 3),
  ('urgente', 'Urgente', '#EF4444', 4);

-- Paleta compartida para crear etiquetas/portadas/colores de workspace
-- (kColorPaletteEtiquetas en kanban_constants.dart) — lista de referencia
-- para poblar selectores de color consistentes en toda la app.
CREATE TABLE color_paleta_catalogo (
  orden     SMALLINT PRIMARY KEY,
  color_hex CHAR(7) NOT NULL UNIQUE
);

INSERT INTO color_paleta_catalogo (orden, color_hex) VALUES
  (1,  '#EF4444'), (2,  '#F59E0B'), (3,  '#EAB308'), (4,  '#22C55E'),
  (5,  '#14B8A6'), (6,  '#3B82F6'), (7,  '#6366F1'), (8,  '#A855F7'),
  (9,  '#EC4899'), (10, '#64748B'), (11, '#DC2626'), (12, '#FB923C'),
  (13, '#84CC16'), (14, '#10B981'), (15, '#06B6D4'), (16, '#0EA5E9'),
  (17, '#8B5CF6'), (18, '#D946EF'), (19, '#F43F5E'), (20, '#334155');


-- ============================================================================
-- 2. USUARIO — directorio de personas COMPARTIDO por toda la app (no por
--    workspace), ver domain/entities/usuario.dart y data/usuario_directorio.dart.
--    Es la pieza que falta para que "la misma persona" en dos áreas de
--    trabajo distintas sea reconocida como una sola identidad, en vez de
--    dos registros [miembro] sin relación.
-- ============================================================================
CREATE TABLE usuario (
  id               BIGSERIAL    PRIMARY KEY,
  nombre           VARCHAR(120) NOT NULL,
  color_avatar_hex CHAR(7)      NOT NULL
);


-- ============================================================================
-- 3. WORKSPACE (área de trabajo) — un tablero Kanban completo e
--    independiente, ver domain/entities/workspace.dart
-- ============================================================================
CREATE TABLE workspace (
  id             BIGSERIAL PRIMARY KEY,
  nombre         VARCHAR(120) NOT NULL,
  color_hex      CHAR(7)      NOT NULL,
  fecha_creacion TIMESTAMPTZ  NOT NULL DEFAULT now()
);
-- Nota: `tareas_count` (Workspace.tareasCount en Dart) NO se persiste aquí
-- a propósito — el repositorio lo recalcula fresco en cada listado en vez
-- de guardarlo, para no duplicar estado que se desincroniza. Ver
-- `vw_workspace_resumen` más abajo, su equivalente en SQL.


-- ============================================================================
-- 4. KANBAN_COLUMNA (listas del tablero) — escaneado por workspace, ver
--    domain/entities/kanban_columna.dart
-- ============================================================================
CREATE TABLE kanban_columna (
  workspace_id BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  -- 'tareas' | 'proceso' | 'pausa' | 'terminado' | 'revisado' (estándar) o
  -- un slug generado para columnas creadas por el usuario (TareaEstatus
  -- .personalizado) — único por workspace, no globalmente.
  estatus_id     VARCHAR(60)  NOT NULL,
  titulo         VARCHAR(80)  NOT NULL,
  icono_nombre   VARCHAR(60)  NOT NULL DEFAULT 'bookmark_rounded', -- nombre del ícono de Material (IconData), no codepoint
  color_hex      CHAR(7)      NOT NULL,
  archivada      BOOLEAN      NOT NULL DEFAULT FALSE,
  -- Límite de tarjetas (WIP) sugerido — NULL = sin límite. La columna
  -- estándar "proceso" nace con límite 1 (regla de negocio: solo una
  -- tarea a la vez en proceso).
  limite_wip     INTEGER,
  orden          INTEGER      NOT NULL, -- posición en el tablero (reordenarColumnas)
  PRIMARY KEY (workspace_id, estatus_id)
);


-- ============================================================================
-- 5. MIEMBRO (personas del catálogo, por workspace) — ver
--    domain/entities/miembro.dart
-- ============================================================================
CREATE TABLE miembro (
  id               BIGSERIAL    PRIMARY KEY,
  workspace_id     BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  nombre           VARCHAR(120) NOT NULL,
  color_avatar_hex CHAR(7)      NOT NULL,
  -- Liga este registro (local a este workspace) con el [usuario] global —
  -- NULL si es alguien que solo existe aquí, sin cuenta en el directorio
  -- compartido. Ver [Miembro.usuarioId].
  usuario_id       BIGINT       REFERENCES usuario(id) ON DELETE SET NULL,
  -- Nivel de participación de esta persona EN ESTE workspace — no es un
  -- atributo del usuario global, la misma persona puede ser 'dueño' de su
  -- propia área y 'invitado' en la de alguien más al mismo tiempo:
  --   'dueño'    → la creó; puede archivarla/eliminarla además de todo lo
  --                que puede un 'miembro'.
  --   'miembro'  → participante pleno: administra columnas/etiquetas/
  --                miembros del catálogo, no solo se asigna tareas.
  --   'invitado' → agregada/o solo porque le tocó una actividad puntual
  --                (ver el escenario de la sección 7.1 más abajo) — puede
  --                ver el tablero y trabajar en lo suyo, pero NO administra
  --                el catálogo de etiquetas/columnas/miembros del área.
  rol              VARCHAR(20)  NOT NULL DEFAULT 'miembro',
  CONSTRAINT chk_rol_miembro CHECK (rol IN ('dueño', 'miembro', 'invitado'))
);


-- ============================================================================
-- 6. USUARIO_ETIQUETA — catálogo PERSONAL de etiquetas de un usuario,
--    reutilizable entre sus áreas de trabajo. Ver la sección 7.1 (comentario
--    largo) para la explicación completa de cómo se relaciona con
--    [tarea_etiqueta] y qué pasa con usuarios invitados.
-- ============================================================================
CREATE TABLE usuario_etiqueta (
  id         BIGSERIAL    PRIMARY KEY,
  usuario_id BIGINT       NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  nombre     VARCHAR(60)  NOT NULL,
  color_hex  CHAR(7)      NOT NULL,
  UNIQUE (usuario_id, nombre)
);


-- ============================================================================
-- 7. TAREA_ETIQUETA (labels del catálogo, por workspace) — ver
--    domain/entities/tarea_etiqueta.dart
-- ============================================================================
CREATE TABLE tarea_etiqueta (
  id           BIGSERIAL    PRIMARY KEY,
  workspace_id BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  nombre       VARCHAR(60)  NOT NULL,
  color_hex    CHAR(7)      NOT NULL,
  -- Si esta etiqueta (local a este workspace) vino de propagar el catálogo
  -- PERSONAL de alguien ("aparecer en todas mis áreas"), aquí queda la
  -- referencia — NULL si nació como una etiqueta suelta, solo de este
  -- workspace (el caso de hoy, sin cambios).
  usuario_etiqueta_id BIGINT REFERENCES usuario_etiqueta(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- 7.1 CÓMO FUNCIONA EL COMPARTIDO DE ETIQUETAS ENTRE WORKSPACES
-- ----------------------------------------------------------------------------
-- Un usuario puede tener VARIAS etiquetas propias (usuario_etiqueta) y
-- reutilizar la misma en distintas áreas de trabajo. `tarea_etiqueta`
-- sigue siendo, como hoy, 100% local a un workspace (una tarea asigna
-- etiquetas por su id LOCAL, igual que siempre) — lo que cambia es que esa
-- fila local puede opcionalmente estar "ligada" a un usuario_etiqueta.
--
-- Al crear una etiqueta se elige entre dos caminos (ver
-- sp_crear_etiqueta_personal más abajo):
--   • "Solo en esta área"       → INSERT normal en tarea_etiqueta,
--                                   usuario_etiqueta_id = NULL. Es el
--                                   comportamiento de hoy, sin cambios.
--   • "En todas mis áreas"      → crea/reutiliza un usuario_etiqueta y
--                                   además una copia local (tarea_etiqueta)
--                                   en cada workspace donde ese usuario ya
--                                   es 'dueño' o 'miembro' (NUNCA en donde
--                                   es 'invitado' — ver más abajo por qué).
--
-- Editar una etiqueta LIGADA (trg_propagar_etiqueta_personal) actualiza el
-- usuario_etiqueta y de ahí se refleja sola en todas sus copias locales —
-- así no hay que ir workspace por workspace a corregir un color. Si en un
-- área puntual se quiere que YA NO seas la misma ("desvincular y editar
-- solo aquí"), basta con poner esa fila local en usuario_etiqueta_id = NULL
-- antes de editarla: a partir de ahí es una etiqueta local independiente,
-- sin tocar las demás copias ni el catálogo personal.
--
-- Eliminar el usuario_etiqueta (desde un catálogo personal, fuera de
-- cualquier workspace en particular) NO borra en cascada las copias locales
-- — quedan huérfanas (usuario_etiqueta_id → NULL, ON DELETE SET NULL) y
-- siguen existiendo como etiquetas normales de cada workspace. Borrar tu
-- plantilla personal no debería vaciar de golpe las etiquetas que ya están
-- puestas en tareas de otras áreas.
--
-- EL CASO DE LA PERSONA INVITADA (el que preguntaste): el departamento de
-- TI necesita que alguien de Calidad complete una sola actividad, así que
-- se le agrega como `miembro` de tipo 'invitado' del workspace de TI.
--   • Qué etiquetas VE en el tablero de TI: exactamente las mismas que ve
--     cualquier otro miembro de TI — tarea_etiqueta es del workspace, no
--     de quien lo mira, así que esto no necesita ningún manejo especial.
--   • Sus etiquetas personales de Calidad (usuario_etiqueta) NO aparecen
--     ni se pueden usar dentro del workspace de TI: nada las propaga ahí
--     porque nunca se le agregaron manualmente a ESE catálogo, y aunque él
--     cree una etiqueta personal nueva mientras trabaja en TI, "todas mis
--     áreas" nunca cuenta un área donde su rol es 'invitado' (ver
--     sp_crear_etiqueta_personal) — así su tablero de Calidad no se llena
--     de etiquetas pensadas para una tarea ajena de TI.
--   • Tampoco puede crear/editar/borrar etiquetas DENTRO del catálogo de
--     TI (trg_bloquear_catalogo_invitado) — un invitado puede aplicar a
--     sus tareas las etiquetas que YA existen en ese workspace, pero no
--     administrar el catálogo compartido de un área a la que no pertenece
--     de verdad. Sí puede seguir creando/editando etiquetas normalmente en
--     los workspaces donde su rol es 'dueño' o 'miembro'.
-- ----------------------------------------------------------------------------


-- ============================================================================
-- 8. TAREA (tarjeta del Kanban) — ver domain/entities/tarea.dart
-- ============================================================================
CREATE TABLE tarea (
  id                    BIGSERIAL    PRIMARY KEY,
  workspace_id          BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  estatus_id            VARCHAR(60)  NOT NULL,
  titulo                VARCHAR(200) NOT NULL,
  descripcion           TEXT         NOT NULL DEFAULT '',
  prioridad_id          VARCHAR(20)  NOT NULL DEFAULT 'media' REFERENCES prioridad_catalogo(id),
  grupo                 VARCHAR(80)  NOT NULL DEFAULT '',
  asignado_por          VARCHAR(120) NOT NULL DEFAULT '',
  fecha_inicio          TIMESTAMPTZ,
  fecha_vencimiento     TIMESTAMPTZ,
  -- Las siguientes dos NO las edita la persona usuaria — las estampa sola
  -- trg_estampar_fechas_reales al cruzar a "proceso" / a un estatus
  -- cerrado (terminado o revisado).
  fecha_inicio_real     TIMESTAMPTZ,
  fecha_fin_real        TIMESTAMPTZ,
  -- Pills libres estilo "Cliente" / "Producción" / etc. — pares
  -- (texto, color) opcionales; en Dart son tuplas `(String, Color)?`.
  generales_texto       VARCHAR(60),
  generales_color_hex   CHAR(7),
  nivel_texto           VARCHAR(60),
  nivel_color_hex       CHAR(7),
  importancia_texto     VARCHAR(60),
  importancia_color_hex CHAR(7),
  orden                 INTEGER      NOT NULL DEFAULT 0, -- posición dentro de su columna
  portada_color_hex     CHAR(7),                          -- color de portada opcional (estilo Trello)
  archivada             BOOLEAN      NOT NULL DEFAULT FALSE,
  -- Las siguientes dos las administra trg_recalcular_bloqueo_subtareas,
  -- nunca se editan directamente desde la aplicación.
  pausada_por_subtarea  BOOLEAN      NOT NULL DEFAULT FALSE,
  estatus_antes_pausa   VARCHAR(60),
  FOREIGN KEY (workspace_id, estatus_id)
    REFERENCES kanban_columna (workspace_id, estatus_id),
  FOREIGN KEY (workspace_id, estatus_antes_pausa)
    REFERENCES kanban_columna (workspace_id, estatus_id)
);


-- ============================================================================
-- 9. TAREA_ACTIVIDAD (subtareas/checklist, árbol vía padre_id — delegación
--    sin límite de profundidad) — equivale a `tar_act` en el sistema
--    original, ver domain/entities/actividad.dart
-- ============================================================================
CREATE TABLE tarea_actividad (
  id           BIGSERIAL    PRIMARY KEY,
  tarea_id     BIGINT       NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  padre_id     BIGINT       REFERENCES tarea_actividad(id) ON DELETE CASCADE, -- NULL = nivel raíz de la tarea
  descripcion  VARCHAR(300) NOT NULL,
  terminada    BOOLEAN      NOT NULL DEFAULT FALSE,
  miembro_id   BIGINT       REFERENCES miembro(id) ON DELETE SET NULL, -- excluyente con departamento
  departamento VARCHAR(80),                                             -- excluyente con miembro_id
  fecha_inicio TIMESTAMPTZ, -- planeadas, se piden al asignar el responsable
  fecha_fin    TIMESTAMPTZ,
  orden        INTEGER      NOT NULL DEFAULT 0,
  CONSTRAINT chk_responsable_excluyente
    CHECK (miembro_id IS NULL OR departamento IS NULL)
);


-- ============================================================================
-- 10. TAREA_HISTORIAL — bitácora de la tarea, ver
--     domain/entities/historial_evento.dart. Se llena SOLA vía los triggers
--     de la sección 15 — ninguna capa de la aplicación inserta aquí a mano.
-- ============================================================================
CREATE TABLE tarea_historial (
  id       BIGSERIAL    PRIMARY KEY,
  tarea_id BIGINT       NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  autor    VARCHAR(120) NOT NULL,
  mensaje  VARCHAR(300) NOT NULL,
  fecha    TIMESTAMPTZ  NOT NULL DEFAULT now()
);


-- ============================================================================
-- 11. RELACIONES N:M
-- ============================================================================

-- Tarea.etiquetaIds
CREATE TABLE tarea_etiqueta_asignada (
  tarea_id    BIGINT NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  etiqueta_id BIGINT NOT NULL REFERENCES tarea_etiqueta(id) ON DELETE CASCADE,
  PRIMARY KEY (tarea_id, etiqueta_id)
);

-- Tarea.miembroIds
CREATE TABLE tarea_miembro_asignado (
  tarea_id   BIGINT NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  miembro_id BIGINT NOT NULL REFERENCES miembro(id) ON DELETE CASCADE,
  PRIMARY KEY (tarea_id, miembro_id)
);

-- Tarea.dependeDeIds: "esta tarea depende de" esas otras (predecesoras
-- para el Gantt).
CREATE TABLE tarea_dependencia (
  tarea_id            BIGINT NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  depende_de_tarea_id BIGINT NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  PRIMARY KEY (tarea_id, depende_de_tarea_id),
  CONSTRAINT chk_no_autodependencia CHECK (tarea_id <> depende_de_tarea_id)
);


-- ============================================================================
-- 12. TAREA_PLANTILLA (templates editables para crear tarjetas rápido) —
--     ver domain/entities/tarea_plantilla.dart
-- ============================================================================
CREATE TABLE tarea_plantilla (
  id                BIGSERIAL    PRIMARY KEY,
  workspace_id      BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  nombre            VARCHAR(120) NOT NULL,
  titulo_sugerido   VARCHAR(200) NOT NULL DEFAULT '',
  descripcion       TEXT         NOT NULL DEFAULT '',
  prioridad_id      VARCHAR(20)  NOT NULL DEFAULT 'media' REFERENCES prioridad_catalogo(id),
  grupo             VARCHAR(80)  NOT NULL DEFAULT '',
  portada_color_hex CHAR(7)
);

-- List<String> actividades (checklist sugerido, sin árbol: la plantilla
-- solo define el nivel raíz, la delegación en subActividades pasa después,
-- ya con la tarea creada).
CREATE TABLE tarea_plantilla_actividad (
  id           BIGSERIAL    PRIMARY KEY,
  plantilla_id BIGINT       NOT NULL REFERENCES tarea_plantilla(id) ON DELETE CASCADE,
  descripcion  VARCHAR(300) NOT NULL,
  orden        INTEGER      NOT NULL DEFAULT 0
);

CREATE TABLE tarea_plantilla_etiqueta (
  plantilla_id BIGINT NOT NULL REFERENCES tarea_plantilla(id) ON DELETE CASCADE,
  etiqueta_id  BIGINT NOT NULL REFERENCES tarea_etiqueta(id) ON DELETE CASCADE,
  PRIMARY KEY (plantilla_id, etiqueta_id)
);

CREATE TABLE tarea_plantilla_miembro (
  plantilla_id BIGINT NOT NULL REFERENCES tarea_plantilla(id) ON DELETE CASCADE,
  miembro_id   BIGINT NOT NULL REFERENCES miembro(id) ON DELETE CASCADE,
  PRIMARY KEY (plantilla_id, miembro_id)
);


-- ============================================================================
-- 13. ÍNDICES
-- ============================================================================
CREATE INDEX idx_tarea_workspace_estatus
  ON tarea (workspace_id, estatus_id) WHERE NOT archivada;
CREATE INDEX idx_tarea_vencimiento
  ON tarea (fecha_vencimiento) WHERE fecha_vencimiento IS NOT NULL AND NOT archivada;
CREATE INDEX idx_tarea_actividad_tarea   ON tarea_actividad (tarea_id);
CREATE INDEX idx_tarea_actividad_padre   ON tarea_actividad (padre_id);
CREATE INDEX idx_tarea_actividad_miembro ON tarea_actividad (miembro_id) WHERE miembro_id IS NOT NULL;
CREATE INDEX idx_tarea_historial_tarea   ON tarea_historial (tarea_id, fecha DESC);
CREATE INDEX idx_tarea_dependencia_depende ON tarea_dependencia (depende_de_tarea_id);
-- KanbanRepository.listarTareas(busqueda: ...) busca por título/grupo.
CREATE INDEX idx_tarea_busqueda
  ON tarea USING gin (to_tsvector('spanish', titulo || ' ' || grupo));
-- Filtrar "áreas de las que soy miembro" (WorkspaceRepository.listarWorkspacesDe)
-- y resolver el catálogo personal de etiquetas son consultas frecuentes.
CREATE INDEX idx_miembro_usuario     ON miembro (usuario_id) WHERE usuario_id IS NOT NULL;
CREATE INDEX idx_tarea_etiqueta_personal ON tarea_etiqueta (usuario_etiqueta_id) WHERE usuario_etiqueta_id IS NOT NULL;


-- ============================================================================
-- 14. VISTA — resumen de workspace (equivalente SQL de Workspace.tareasCount)
-- ============================================================================
CREATE VIEW vw_workspace_resumen AS
SELECT
  w.id,
  w.nombre,
  w.color_hex,
  w.fecha_creacion,
  COUNT(t.id) FILTER (WHERE NOT t.archivada) AS tareas_count
FROM workspace w
LEFT JOIN tarea t ON t.workspace_id = w.id
GROUP BY w.id;


-- ============================================================================
-- 15. TRIGGERS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 15.1 Límite de WIP — hoy en Dart se valida por separado en 4 puntos de
-- entrada (arrastrar tarjeta, mover en lote, botón Iniciar/Reabrir, crear
-- tarea nueva). A nivel de base de datos se centraliza en un único trigger:
-- cualquier INSERT/UPDATE que deje una tarea en una columna con
-- limite_wip lleno se rechaza, sin importar el camino por el que llegó.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_wip_tarea() RETURNS TRIGGER AS $$
DECLARE
  v_limite   INTEGER;
  v_ocupadas INTEGER;
BEGIN
  IF NEW.archivada THEN
    RETURN NEW;
  END IF;

  SELECT limite_wip INTO v_limite
  FROM kanban_columna
  WHERE workspace_id = NEW.workspace_id AND estatus_id = NEW.estatus_id;

  IF v_limite IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO v_ocupadas
  FROM tarea
  WHERE workspace_id = NEW.workspace_id
    AND estatus_id = NEW.estatus_id
    AND NOT archivada
    AND id <> COALESCE(NEW.id, -1);

  IF v_ocupadas >= v_limite THEN
    RAISE EXCEPTION 'Límite de WIP alcanzado en la columna "%": ya hay % de % tareas permitidas.',
      NEW.estatus_id, v_ocupadas, v_limite
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_wip_tarea
  BEFORE INSERT OR UPDATE OF estatus_id, archivada ON tarea
  FOR EACH ROW
  WHEN (NOT NEW.archivada)
  EXECUTE FUNCTION fn_validar_wip_tarea();

-- ---------------------------------------------------------------------------
-- 15.2 Estampado de fechas reales (fecha_inicio_real / fecha_fin_real) y
-- limpieza de fecha_fin_real al reabrir una tarea cerrada (sin esto, el
-- banner "Terminado el... a las..." se queda pegado tras reabrir).
--
-- NOTA DE DISEÑO — divergencia intencional del repositorio en memoria: hoy
-- `InMemoryKanbanRepository` NO limpia `fechaFinReal` al reabrir (lo deja
-- con el sello del cierre anterior) y en su lugar obliga a cada consumidor
-- (Gantt, Gráficas) a comprobar primero `tarea.cerrada` antes de confiar en
-- ese campo — un rodeo razonable en memoria, donde limpiar-y-reponer en
-- cada sitio que lo usa es más código que un solo campo derivado. A nivel
-- de base de datos SÍ conviene limpiarlo aquí: así `fecha_fin_real IS NOT
-- NULL` significa siempre, sin excepción, "sigue cerrada Y esta es su
-- fecha real de cierre vigente" — un único invariante que cualquier
-- consulta puede confiar ciegamente, sin repetir el chequeo de `cerrada`
-- en cada lugar que lo lea. El día que un backend real implemente
-- `KanbanRepository`, el cliente Dart puede simplificarse para apoyarse en
-- este invariante en vez de mantener su propio rodeo.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_estampar_fechas_reales() RETURNS TRIGGER AS $$
DECLARE
  v_cerrado_antes BOOLEAN;
  v_cerrado_ahora BOOLEAN;
BEGIN
  v_cerrado_ahora := NEW.estatus_id IN ('terminado', 'revisado');

  IF NEW.estatus_id = 'proceso' AND NEW.fecha_inicio_real IS NULL THEN
    NEW.fecha_inicio_real := now();
  END IF;

  IF v_cerrado_ahora AND NEW.fecha_fin_real IS NULL THEN
    NEW.fecha_fin_real := now();
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_cerrado_antes := OLD.estatus_id IN ('terminado', 'revisado');
    IF v_cerrado_antes AND NOT v_cerrado_ahora THEN
      NEW.fecha_fin_real := NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estampar_fechas_reales
  BEFORE INSERT OR UPDATE OF estatus_id ON tarea
  FOR EACH ROW
  EXECUTE FUNCTION fn_estampar_fechas_reales();

-- ---------------------------------------------------------------------------
-- 15.3 Auto-pausa por subtarea bloqueante: cuando una actividad (a
-- cualquier profundidad del árbol) tiene responsable asignado y sigue sin
-- terminarse, la tarea se pausa sola; al resolverse la última bloqueante,
-- regresa a su estatus previo. Es independiente de una pausa manual (esa
-- la decide la persona y no se revierte sola) — se distinguen con
-- `pausada_por_subtarea`.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_recalcular_bloqueo_subtareas() RETURNS TRIGGER AS $$
DECLARE
  v_tarea_id          BIGINT;
  v_bloqueada         BOOLEAN;
  v_tarea             tarea%ROWTYPE;
  v_destino_archivada BOOLEAN;
BEGIN
  v_tarea_id := COALESCE(NEW.tarea_id, OLD.tarea_id);

  WITH RECURSIVE arbol AS (
    SELECT id, terminada, miembro_id, departamento
    FROM tarea_actividad
    WHERE tarea_id = v_tarea_id AND padre_id IS NULL
    UNION ALL
    SELECT a.id, a.terminada, a.miembro_id, a.departamento
    FROM tarea_actividad a
    JOIN arbol ON a.padre_id = arbol.id
  )
  SELECT EXISTS (
    SELECT 1 FROM arbol
    WHERE NOT terminada AND (miembro_id IS NOT NULL OR departamento IS NOT NULL)
  ) INTO v_bloqueada;

  SELECT * INTO v_tarea FROM tarea WHERE id = v_tarea_id;

  IF v_bloqueada AND NOT v_tarea.pausada_por_subtarea AND v_tarea.estatus_id <> 'pausa' THEN
    -- No autopausar dentro de una columna archivada: la tarjeta quedaría
    -- invisible en el tablero (ni en él ni en "tarjetas archivadas", porque
    -- `tarea.archivada` sigue en FALSE) sin ningún aviso — se queda donde
    -- está hasta que se desarchive "Pausa" o el bloqueo se resuelva de otra
    -- forma. Mismo criterio que `_columnaArchivada` en el repositorio Dart
    -- (`in_memory_kanban_repository.dart`, función `_reubicarEnColumna`).
    SELECT archivada INTO v_destino_archivada
    FROM kanban_columna
    WHERE workspace_id = v_tarea.workspace_id AND estatus_id = 'pausa';

    IF NOT COALESCE(v_destino_archivada, FALSE) THEN
      UPDATE tarea
      SET estatus_antes_pausa = estatus_id,
          estatus_id = 'pausa',
          pausada_por_subtarea = TRUE
      WHERE id = v_tarea_id;
    END IF;
  ELSIF NOT v_bloqueada AND v_tarea.pausada_por_subtarea THEN
    -- Mismo motivo que arriba: no reanudar hacia una columna archivada.
    SELECT archivada INTO v_destino_archivada
    FROM kanban_columna
    WHERE workspace_id = v_tarea.workspace_id
      AND estatus_id = COALESCE(v_tarea.estatus_antes_pausa, 'tareas');

    IF NOT COALESCE(v_destino_archivada, FALSE) THEN
      UPDATE tarea
      SET estatus_id = COALESCE(estatus_antes_pausa, 'tareas'),
          estatus_antes_pausa = NULL,
          pausada_por_subtarea = FALSE
      WHERE id = v_tarea_id;
    END IF;
  END IF;

  RETURN NULL; -- trigger AFTER: no modifica la fila que lo disparó
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalcular_bloqueo_subtareas
  AFTER INSERT OR DELETE OR UPDATE OF terminada, miembro_id, departamento
  ON tarea_actividad
  FOR EACH ROW
  EXECUTE FUNCTION fn_recalcular_bloqueo_subtareas();

-- ---------------------------------------------------------------------------
-- 15.4 Historial automático — nunca se escribe a mano desde la aplicación.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_historial_cambio_tarea() RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estatus_id IS DISTINCT FROM NEW.estatus_id THEN
    INSERT INTO tarea_historial (tarea_id, autor, mensaje)
    VALUES (NEW.id, current_setting('app.usuario_actual', true),
            format('Movida de "%s" a "%s"', OLD.estatus_id, NEW.estatus_id));
  END IF;

  IF OLD.prioridad_id IS DISTINCT FROM NEW.prioridad_id THEN
    INSERT INTO tarea_historial (tarea_id, autor, mensaje)
    VALUES (NEW.id, current_setting('app.usuario_actual', true),
            format('Prioridad cambiada a "%s"', NEW.prioridad_id));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_historial_cambio_tarea
  AFTER UPDATE ON tarea
  FOR EACH ROW
  EXECUTE FUNCTION fn_historial_cambio_tarea();

CREATE OR REPLACE FUNCTION fn_historial_actividad() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO tarea_historial (tarea_id, autor, mensaje)
    VALUES (NEW.tarea_id, current_setting('app.usuario_actual', true),
            format('Agregó la subtarea "%s"', NEW.descripcion));
  ELSIF TG_OP = 'UPDATE' AND OLD.terminada IS DISTINCT FROM NEW.terminada THEN
    INSERT INTO tarea_historial (tarea_id, autor, mensaje)
    VALUES (NEW.tarea_id, current_setting('app.usuario_actual', true),
            format('%s la subtarea "%s"',
                   CASE WHEN NEW.terminada THEN 'Completó' ELSE 'Reabrió' END,
                   NEW.descripcion));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_historial_actividad
  AFTER INSERT OR UPDATE OF terminada ON tarea_actividad
  FOR EACH ROW
  EXECUTE FUNCTION fn_historial_actividad();

-- ---------------------------------------------------------------------------
-- 15.5 Evitar dependencias circulares en el Gantt (A depende de B que
-- depende de A) antes de insertarlas.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevenir_dependencia_circular() RETURNS TRIGGER AS $$
DECLARE
  v_ciclo BOOLEAN;
BEGIN
  WITH RECURSIVE cadena AS (
    SELECT depende_de_tarea_id AS id FROM tarea_dependencia
    WHERE tarea_id = NEW.depende_de_tarea_id
    UNION ALL
    SELECT td.depende_de_tarea_id
    FROM tarea_dependencia td
    JOIN cadena c ON td.tarea_id = c.id
  )
  SELECT EXISTS (SELECT 1 FROM cadena WHERE id = NEW.tarea_id) INTO v_ciclo;

  IF v_ciclo THEN
    RAISE EXCEPTION 'Dependencia circular: la tarea % ya depende (directa o indirectamente) de %.',
      NEW.depende_de_tarea_id, NEW.tarea_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevenir_dependencia_circular
  BEFORE INSERT ON tarea_dependencia
  FOR EACH ROW
  EXECUTE FUNCTION fn_prevenir_dependencia_circular();

-- ---------------------------------------------------------------------------
-- 15.6 Propagar cambios de una etiqueta PERSONAL a todas sus copias locales
-- ligadas (ver la nota larga de la sección 7.1) — así renombrar/recolorear
-- desde el catálogo personal se refleja solo en cada workspace donde ya se
-- había compartido, sin ir uno por uno.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_propagar_etiqueta_personal() RETURNS TRIGGER AS $$
BEGIN
  IF OLD.nombre IS DISTINCT FROM NEW.nombre
     OR OLD.color_hex IS DISTINCT FROM NEW.color_hex THEN
    UPDATE tarea_etiqueta
    SET nombre = NEW.nombre, color_hex = NEW.color_hex
    WHERE usuario_etiqueta_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_propagar_etiqueta_personal
  AFTER UPDATE ON usuario_etiqueta
  FOR EACH ROW
  EXECUTE FUNCTION fn_propagar_etiqueta_personal();

-- ---------------------------------------------------------------------------
-- 15.7 Un 'invitado' puede APLICAR etiquetas ya existentes a sus tareas,
-- pero no administrar el catálogo (crear/renombrar/eliminar) de un
-- workspace al que solo pertenece de forma limitada — ver la nota larga de
-- la sección 7.1. `app.usuario_actual_id` es el equivalente en id de la
-- sesión simulada al `app.usuario_actual` (nombre) que ya usan los
-- triggers de historial.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_bloquear_catalogo_invitado() RETURNS TRIGGER AS $$
DECLARE
  v_workspace_id BIGINT;
  -- NULLIF antes del cast: `current_setting(..., true)` sin la variable
  -- fijada puede devolver cadena vacía en vez de NULL según la sesión, y
  -- '' ::BIGINT truena en vez de dar NULL.
  v_usuario_id   BIGINT := NULLIF(current_setting('app.usuario_actual_id', true), '')::BIGINT;
  v_rol          VARCHAR(20);
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_workspace_id := OLD.workspace_id;
  ELSE
    v_workspace_id := NEW.workspace_id;
  END IF;

  -- Sin sesión (p. ej. una migración de datos o sp_crear_tarea_desde_plantilla
  -- corriendo por su cuenta) no hay quién sea "invitado", así que no restringe.
  IF v_usuario_id IS NOT NULL THEN
    SELECT rol INTO v_rol
    FROM miembro
    WHERE workspace_id = v_workspace_id AND usuario_id = v_usuario_id;

    IF v_rol = 'invitado' THEN
      RAISE EXCEPTION 'Un invitado no puede administrar el catálogo de etiquetas de este workspace.'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_catalogo_invitado
  BEFORE INSERT OR UPDATE OR DELETE ON tarea_etiqueta
  FOR EACH ROW
  EXECUTE FUNCTION fn_bloquear_catalogo_invitado();

-- ---------------------------------------------------------------------------
-- 15.8 Ninguna tarea (crear o mover) puede terminar en una columna
-- archivada — mismo invariante que ya reforzaba el trigger de WIP (15.1),
-- pero independiente de si esa columna tiene límite o no. Espeja
-- `_reubicarEnColumna`/`crearTarea` del repositorio Dart: ahí un intento de
-- mover hacia una columna archivada se resuelve devolviendo `false` sin
-- tocar nada (`moverTarea`), y crear ahí lanza una excepción (`crearTarea`)
-- — aquí, al ser siempre un INSERT/UPDATE directo, ambos casos se modelan
-- como una excepción; es responsabilidad de la capa de API traducirla al
-- `false`/error que cada llamador de Dart espera. IMPORTANTE: por esto
-- mismo, 15.3 (auto-pausa/reanudación) pre-chequea `archivada` ANTES de su
-- propio UPDATE en vez de dejar que este trigger la detenga — si no, una
-- auto-pausa hacia una columna archivada abortaría de golpe toda la
-- transacción que la disparó (p. ej. marcar una subtarea como terminada),
-- deshaciendo también el cambio que sí era válido.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevenir_tarea_en_columna_archivada() RETURNS TRIGGER AS $$
DECLARE
  v_archivada BOOLEAN;
BEGIN
  IF NEW.archivada THEN
    -- Archivar la TARJETA (archivarTarea) es un camino aparte que sigue
    -- funcionando sin importar el estado de su columna.
    RETURN NEW;
  END IF;

  SELECT archivada INTO v_archivada
  FROM kanban_columna
  WHERE workspace_id = NEW.workspace_id AND estatus_id = NEW.estatus_id;

  IF v_archivada THEN
    -- SQLSTATE propio ('KB001', no el genérico check_violation que ya usa
    -- el trigger de WIP): así `sp_mover_tarea` puede atrapar ESTE caso
    -- puntual y devolver `false` (igual que `KanbanRepository.moverTarea`)
    -- sin también silenciar por accidente un límite de WIP excedido, que
    -- debe seguir siendo un error real.
    RAISE EXCEPTION 'La columna "%" está archivada; no se puede crear ni mover una tarjeta ahí.',
      NEW.estatus_id
      USING ERRCODE = 'KB001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevenir_tarea_en_columna_archivada
  BEFORE INSERT OR UPDATE OF estatus_id, archivada ON tarea
  FOR EACH ROW
  EXECUTE FUNCTION fn_prevenir_tarea_en_columna_archivada();

-- ---------------------------------------------------------------------------
-- 15.9 No se puede archivar la última columna VISIBLE de un workspace —
-- sin este guard, el tablero podía quedar sin ningún lugar donde soltar o
-- crear tarjetas nuevas. Espeja el chequeo `_columnasVisibles.length <= 1`
-- de `kanban_dashboard/columnas.dart` en Dart.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevenir_archivar_ultima_columna() RETURNS TRIGGER AS $$
DECLARE
  v_visibles_restantes INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_visibles_restantes
  FROM kanban_columna
  WHERE workspace_id = NEW.workspace_id
    AND NOT archivada
    AND estatus_id <> NEW.estatus_id;

  IF v_visibles_restantes = 0 THEN
    RAISE EXCEPTION 'No puedes archivar "%": el tablero quedaría sin ninguna lista visible.',
      NEW.estatus_id
      USING ERRCODE = 'KB002';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevenir_archivar_ultima_columna
  BEFORE UPDATE OF archivada ON kanban_columna
  FOR EACH ROW
  WHEN (NEW.archivada AND NOT OLD.archivada)
  EXECUTE FUNCTION fn_prevenir_archivar_ultima_columna();

-- ---------------------------------------------------------------------------
-- 15.10 No se puede quitar a la última persona con `usuario_id` (ligada al
-- directorio global) de un workspace — sin este guard, el área quedaba sin
-- nadie a quien `listarWorkspacesDe` se la mostrara nunca más: ni siquiera
-- a quien la acababa de quitar. El área seguiría existiendo (con todas sus
-- tareas) pero inaccesible para siempre. Espeja el guard de
-- `WorkspaceMiembrosDialog._quitar` en Dart.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevenir_quitar_ultimo_acceso() RETURNS TRIGGER AS $$
DECLARE
  v_quedan_con_acceso INTEGER;
BEGIN
  IF OLD.usuario_id IS NULL THEN
    -- Este miembro no ligaba a nadie del directorio global; no afecta el
    -- invariante de "alguien puede seguir entrando a esta área".
    RETURN OLD;
  END IF;

  SELECT COUNT(*) INTO v_quedan_con_acceso
  FROM miembro
  WHERE workspace_id = OLD.workspace_id
    AND usuario_id IS NOT NULL
    AND id <> OLD.id;

  IF v_quedan_con_acceso = 0 THEN
    RAISE EXCEPTION 'No puedes quitar a la última persona con acceso a esta área de trabajo: quedaría inaccesible para siempre.'
      USING ERRCODE = 'KB003';
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevenir_quitar_ultimo_acceso
  BEFORE DELETE ON miembro
  FOR EACH ROW
  EXECUTE FUNCTION fn_prevenir_quitar_ultimo_acceso();


-- ============================================================================
-- 16. PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 16.1 sp_mover_tarea — equivalente a KanbanRepository.moverTarea: reordena
-- dentro de la columna destino; los triggers de la sección 15 validan WIP,
-- estampan fechas reales y registran historial automáticamente.
--
-- Devuelve BOOLEAN (no es un PROCEDURE sin valor de retorno) para
-- respetar el mismo contrato que `Future<bool> moverTarea(...)` en Dart:
-- `false` si la columna destino está archivada (trg_prevenir_tarea_en_
-- columna_archivada, 15.8), sin lanzar — así quien llama (p. ej. mover
-- varias tarjetas en lote) puede distinguir "esta no se movió" del resto
-- y seguir con las demás, en vez de que la excepción aborte todo el lote.
-- Cualquier OTRA excepción (WIP excedido, tarea inexistente, etc.) sí se
-- propaga normal — solo se atrapa el SQLSTATE específico de "archivada".
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_mover_tarea(
  p_tarea_id      BIGINT,
  p_nuevo_estatus VARCHAR(60),
  p_posicion      INTEGER DEFAULT NULL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_workspace_id BIGINT;
  v_siguiente    INTEGER;
BEGIN
  SELECT workspace_id INTO v_workspace_id FROM tarea WHERE id = p_tarea_id;

  SELECT COALESCE(MAX(orden), -1) + 1 INTO v_siguiente
  FROM tarea WHERE workspace_id = v_workspace_id AND estatus_id = p_nuevo_estatus;

  UPDATE tarea
  SET estatus_id = p_nuevo_estatus,
      orden = COALESCE(p_posicion, v_siguiente)
  WHERE id = p_tarea_id;

  RETURN TRUE;
EXCEPTION
  WHEN SQLSTATE 'KB001' THEN
    RETURN FALSE;
END;
$$;

-- ---------------------------------------------------------------------------
-- 16.2 fn_progreso_tarea — % de actividades terminadas (recursivo, incluye
-- subActividades a cualquier profundidad) — espeja el getter Tarea.progreso.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_progreso_tarea(p_tarea_id BIGINT)
RETURNS NUMERIC LANGUAGE sql AS $$
  WITH RECURSIVE arbol AS (
    SELECT id, terminada FROM tarea_actividad
    WHERE tarea_id = p_tarea_id AND padre_id IS NULL
    UNION ALL
    SELECT a.id, a.terminada FROM tarea_actividad a
    JOIN arbol ON a.padre_id = arbol.id
  )
  SELECT CASE WHEN COUNT(*) = 0 THEN 0
              ELSE COUNT(*) FILTER (WHERE terminada)::NUMERIC / COUNT(*)
         END
  FROM arbol;
$$;

-- ---------------------------------------------------------------------------
-- 16.3 sp_actualizar_tarea_cascada — al mover la fecha de vencimiento de
-- una tarea, empuja la misma diferencia de tiempo a sus sucesoras (tareas
-- cuyo dependeDeIds la incluye) y devuelve cuántas tocó — igual que el
-- comentario de KanbanRepository.actualizarTarea describe para el Gantt.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_actualizar_tarea_cascada(
  p_tarea_id                 BIGINT,
  p_nueva_fecha_vencimiento  TIMESTAMPTZ
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_fecha_anterior TIMESTAMPTZ;
  v_delta          INTERVAL;
  v_afectadas      INTEGER := 0;
  v_sucesor_id     BIGINT;
BEGIN
  SELECT fecha_vencimiento INTO v_fecha_anterior FROM tarea WHERE id = p_tarea_id;
  v_delta := p_nueva_fecha_vencimiento - v_fecha_anterior;

  UPDATE tarea SET fecha_vencimiento = p_nueva_fecha_vencimiento WHERE id = p_tarea_id;

  IF v_delta IS NOT NULL AND v_delta <> INTERVAL '0' THEN
    FOR v_sucesor_id IN
      SELECT t.id FROM tarea t
      JOIN tarea_dependencia td ON td.tarea_id = t.id
      WHERE td.depende_de_tarea_id = p_tarea_id
    LOOP
      UPDATE tarea
      SET fecha_vencimiento = fecha_vencimiento + v_delta,
          fecha_inicio = fecha_inicio + v_delta
      WHERE id = v_sucesor_id;
      v_afectadas := v_afectadas + 1;
    END LOOP;
  END IF;

  RETURN v_afectadas;
END;
$$;

-- ---------------------------------------------------------------------------
-- 16.4 sp_crear_tarea_desde_plantilla — clona una TareaPlantilla en una
-- tarea nueva (checklist, etiquetas y miembros sugeridos incluidos). El
-- INSERT en `tarea` ya dispara trg_validar_wip_tarea, así que crear desde
-- plantilla respeta el límite de WIP igual que crear una tarea a mano.
--
-- A diferencia de `NuevaTareaDialog` en Dart (que precarga `tituloSugerido`
-- en el campo de texto pero exige que la persona confirme algo no vacío
-- antes de guardar), esta función no pasa por ningún formulario — si la
-- plantilla no trae `titulo_sugerido`, usa el propio nombre de la
-- plantilla como título en vez de violar el CHECK de la sección 17.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_crear_tarea_desde_plantilla(
  p_plantilla_id BIGINT,
  p_workspace_id BIGINT,
  p_estatus_id   VARCHAR(60),
  p_asignado_por VARCHAR(120)
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
  v_plantilla tarea_plantilla%ROWTYPE;
  v_tarea_id  BIGINT;
BEGIN
  SELECT * INTO v_plantilla FROM tarea_plantilla WHERE id = p_plantilla_id;

  INSERT INTO tarea (
    workspace_id, estatus_id, titulo, descripcion, prioridad_id, grupo,
    asignado_por, portada_color_hex
  ) VALUES (
    p_workspace_id, p_estatus_id,
    COALESCE(NULLIF(btrim(v_plantilla.titulo_sugerido), ''), v_plantilla.nombre),
    v_plantilla.descripcion,
    v_plantilla.prioridad_id, v_plantilla.grupo, p_asignado_por, v_plantilla.portada_color_hex
  ) RETURNING id INTO v_tarea_id;

  INSERT INTO tarea_actividad (tarea_id, descripcion, orden)
  SELECT v_tarea_id, descripcion, orden
  FROM tarea_plantilla_actividad WHERE plantilla_id = p_plantilla_id;

  INSERT INTO tarea_etiqueta_asignada (tarea_id, etiqueta_id)
  SELECT v_tarea_id, etiqueta_id
  FROM tarea_plantilla_etiqueta WHERE plantilla_id = p_plantilla_id;

  INSERT INTO tarea_miembro_asignado (tarea_id, miembro_id)
  SELECT v_tarea_id, miembro_id
  FROM tarea_plantilla_miembro WHERE plantilla_id = p_plantilla_id;

  RETURN v_tarea_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 16.5 sp_crear_workspace — inserta el área de trabajo + sus 5 columnas
-- estándar (mismo título/color/límite que siembra kColumnas en
-- kanban_constants.dart) y agrega automáticamente a quien la crea como su
-- 'dueño' — sin esto, alguien podía crear un área y quedar sin membresía
-- (y por lo tanto invisible) en su propio selector de áreas. El fallback
-- de nombre vacío ("Área de trabajo") espeja
-- `WorkspaceRepository.crearWorkspace` en Dart — el CHECK de la sección 17
-- es la red de seguridad si algún otro cliente/API se salta este fallback.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_crear_workspace(
  p_nombre           VARCHAR(120),
  p_color_hex        CHAR(7),
  p_creador_usuario_id BIGINT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
  v_workspace_id BIGINT;
  v_creador      usuario%ROWTYPE;
BEGIN
  INSERT INTO workspace (nombre, color_hex)
  VALUES (COALESCE(NULLIF(btrim(p_nombre), ''), 'Área de trabajo'), p_color_hex)
  RETURNING id INTO v_workspace_id;

  INSERT INTO kanban_columna
    (workspace_id, estatus_id, titulo, icono_nombre, color_hex, limite_wip, orden)
  VALUES
    (v_workspace_id, 'tareas',    'TAREAS',     'bookmark_rounded', '#343A40', NULL, 1),
    (v_workspace_id, 'proceso',   'PROCESO',    'bookmark_rounded', '#2196F3', 1,    2),
    (v_workspace_id, 'pausa',     'PAUSA',      'bookmark_rounded', '#FD7E14', NULL, 3),
    (v_workspace_id, 'terminado', 'TERMINADO',  'bookmark_rounded', '#17A2B8', NULL, 4),
    (v_workspace_id, 'revisado',  'REVISADO',   'bookmark_rounded', '#28A745', NULL, 5);

  IF p_creador_usuario_id IS NOT NULL THEN
    SELECT * INTO v_creador FROM usuario WHERE id = p_creador_usuario_id;
    INSERT INTO miembro (workspace_id, nombre, color_avatar_hex, usuario_id, rol)
    VALUES (v_workspace_id, v_creador.nombre, v_creador.color_avatar_hex, v_creador.id, 'dueño');
  END IF;

  RETURN v_workspace_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 16.6 sp_crear_etiqueta_personal — crea (o reutiliza, si el nombre ya
-- existe en su catálogo) una etiqueta PERSONAL del usuario y la propaga
-- como copia local a cada workspace donde ya es 'dueño' o 'miembro' pleno
-- — NUNCA a uno donde es 'invitado' (ver la nota larga de la sección 7.1).
-- Es idempotente: volver a llamarla no duplica copias ya existentes.
--
-- Colisión de nombre: si el workspace destino YA tiene una etiqueta local
-- sin vincular con el mismo nombre (sin importar mayúsculas/minúsculas),
-- no se crea una segunda — esa etiqueta existente se ADOPTA (se liga al
-- catálogo personal y toma su color) en vez de dejar dos etiquetas con el
-- mismo nombre en el mismo tablero. Si dos nombres iguales de verdad
-- significan cosas distintas para cada quien, la persona dueña de ese
-- workspace puede desvincularla después (usuario_etiqueta_id → NULL) y
-- renombrar la que corresponda.
--
-- Para "solo en esta área" no hace falta procedimiento — es un INSERT
-- normal en tarea_etiqueta con usuario_etiqueta_id en NULL, igual que hoy.
--
-- Cambios de rol: pasar de 'invitado' a 'miembro' no vincula
-- retroactivamente nada — la próxima vez que la persona use "todas mis
-- áreas" para una etiqueta (nueva o existente), ese workspace ya cuenta.
-- Pasar de 'miembro' a 'invitado' tampoco desvincula lo ya propagado: las
-- copias locales siguen funcionando como etiquetas normales de ese
-- workspace (trg_bloquear_catalogo_invitado ya le impide seguir
-- administrando el catálogo desde ese momento, que es lo que importa) —
-- mismo criterio de "no borrar en cascada" que ya se usa en el resto del
-- esquema (ver ON DELETE SET NULL de usuario_etiqueta_id).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_crear_etiqueta_personal(
  p_usuario_id BIGINT,
  p_nombre     VARCHAR(60),
  p_color_hex  CHAR(7)
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
  v_usuario_etiqueta_id BIGINT;
  v_workspace_id        BIGINT;
  v_local_id            BIGINT;
BEGIN
  INSERT INTO usuario_etiqueta (usuario_id, nombre, color_hex)
  VALUES (p_usuario_id, p_nombre, p_color_hex)
  ON CONFLICT (usuario_id, nombre) DO UPDATE SET color_hex = EXCLUDED.color_hex
  RETURNING id INTO v_usuario_etiqueta_id;

  FOR v_workspace_id IN
    SELECT m.workspace_id FROM miembro m
    WHERE m.usuario_id = p_usuario_id AND m.rol IN ('dueño', 'miembro')
  LOOP
    -- Ya propagada aquí en una llamada anterior: nada que hacer.
    PERFORM 1 FROM tarea_etiqueta
    WHERE workspace_id = v_workspace_id AND usuario_etiqueta_id = v_usuario_etiqueta_id;
    IF FOUND THEN
      CONTINUE;
    END IF;

    -- ¿Existe ya una etiqueta local con este nombre, sin vincular? Se
    -- adopta en vez de duplicar (ver el comentario de la función).
    SELECT id INTO v_local_id
    FROM tarea_etiqueta
    WHERE workspace_id = v_workspace_id
      AND lower(nombre) = lower(p_nombre)
      AND usuario_etiqueta_id IS NULL
    LIMIT 1;

    IF v_local_id IS NOT NULL THEN
      UPDATE tarea_etiqueta
      SET usuario_etiqueta_id = v_usuario_etiqueta_id,
          color_hex = p_color_hex
      WHERE id = v_local_id;
    ELSE
      INSERT INTO tarea_etiqueta (workspace_id, nombre, color_hex, usuario_etiqueta_id)
      VALUES (v_workspace_id, p_nombre, p_color_hex, v_usuario_etiqueta_id);
    END IF;
  END LOOP;

  RETURN v_usuario_etiqueta_id;
END;
$$;


-- ============================================================================
-- 17. RESTRICCIONES ADICIONALES DE INTEGRIDAD
-- ============================================================================
-- Defensa en profundidad: hoy Dart ya evita nombres vacíos ANTES de llamar
-- al repositorio (`crearWorkspace` → "Área de trabajo", `crearColumna` →
-- "Nueva lista", `crearEtiqueta` → "Nueva etiqueta", ver los comentarios
-- correspondientes en `in_memory_kanban_repository.dart`/
-- `workspace_repository.dart`). Estos CHECK no duplican esa lógica de
-- fallback (elegir el texto por defecto es una decisión de producto, no de
-- almacenamiento) — solo garantizan que, sin importar qué cliente/API
-- termine escribiendo aquí, nunca quede persistido un nombre en blanco que
-- sería invisible/inseleccionable en la UI.
ALTER TABLE workspace       ADD CONSTRAINT chk_workspace_nombre       CHECK (btrim(nombre) <> '');
ALTER TABLE kanban_columna  ADD CONSTRAINT chk_columna_titulo         CHECK (btrim(titulo) <> '');
ALTER TABLE tarea           ADD CONSTRAINT chk_tarea_titulo           CHECK (btrim(titulo) <> '');
ALTER TABLE tarea_etiqueta  ADD CONSTRAINT chk_etiqueta_nombre        CHECK (btrim(nombre) <> '');
ALTER TABLE miembro         ADD CONSTRAINT chk_miembro_nombre         CHECK (btrim(nombre) <> '');
ALTER TABLE usuario         ADD CONSTRAINT chk_usuario_nombre         CHECK (btrim(nombre) <> '');
ALTER TABLE tarea_plantilla ADD CONSTRAINT chk_plantilla_nombre       CHECK (btrim(nombre) <> '');
