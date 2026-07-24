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
-- (hoy implementados en memoria vía InMemoryKanbanRepository /
-- InMemoryWorkspaceRepository) — pensado para el día que ese mismo
-- contrato se respalde con un backend/API real, sin tocar la capa de
-- presentación (ver el comentario de diseño en kanban_repository.dart).
--
-- No incluye login/usuarios: los campos "autor"/"asignado_por" hoy son
-- texto libre (no hay tabla de usuarios en el módulo todavía) — cuando
-- exista autenticación real, esos campos pasan a ser FKs a esa tabla.
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
-- 2. WORKSPACE (área de trabajo) — un tablero Kanban completo e
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
-- 3. KANBAN_COLUMNA (listas del tablero) — escaneado por workspace, ver
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
-- 4. MIEMBRO (personas del catálogo, por workspace) — ver
--    domain/entities/miembro.dart
-- ============================================================================
CREATE TABLE miembro (
  id               BIGSERIAL    PRIMARY KEY,
  workspace_id     BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  nombre           VARCHAR(120) NOT NULL,
  color_avatar_hex CHAR(7)      NOT NULL
);


-- ============================================================================
-- 5. TAREA_ETIQUETA (labels del catálogo, por workspace) — ver
--    domain/entities/tarea_etiqueta.dart
-- ============================================================================
CREATE TABLE tarea_etiqueta (
  id           BIGSERIAL    PRIMARY KEY,
  workspace_id BIGINT       NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  nombre       VARCHAR(60)  NOT NULL,
  color_hex    CHAR(7)      NOT NULL
);


-- ============================================================================
-- 6. TAREA (tarjeta del Kanban) — ver domain/entities/tarea.dart
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
-- 7. TAREA_ACTIVIDAD (subtareas/checklist, árbol vía padre_id — delegación
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
-- 8. TAREA_HISTORIAL — bitácora de la tarea, ver
--    domain/entities/historial_evento.dart. Se llena SOLA vía los triggers
--    de la sección 13 — ninguna capa de la aplicación inserta aquí a mano.
-- ============================================================================
CREATE TABLE tarea_historial (
  id       BIGSERIAL    PRIMARY KEY,
  tarea_id BIGINT       NOT NULL REFERENCES tarea(id) ON DELETE CASCADE,
  autor    VARCHAR(120) NOT NULL,
  mensaje  VARCHAR(300) NOT NULL,
  fecha    TIMESTAMPTZ  NOT NULL DEFAULT now()
);


-- ============================================================================
-- 9. RELACIONES N:M
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
-- 10. TAREA_PLANTILLA (templates editables para crear tarjetas rápido) —
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
-- 11. ÍNDICES
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


-- ============================================================================
-- 12. VISTA — resumen de workspace (equivalente SQL de Workspace.tareasCount)
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
-- 13. TRIGGERS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 13.1 Límite de WIP — hoy en Dart se valida por separado en 4 puntos de
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
-- 13.2 Estampado de fechas reales (fecha_inicio_real / fecha_fin_real) y
-- limpieza de fecha_fin_real al reabrir una tarea cerrada (sin esto, el
-- banner "Terminado el... a las..." se queda pegado tras reabrir).
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
-- 13.3 Auto-pausa por subtarea bloqueante: cuando una actividad (a
-- cualquier profundidad del árbol) tiene responsable asignado y sigue sin
-- terminarse, la tarea se pausa sola; al resolverse la última bloqueante,
-- regresa a su estatus previo. Es independiente de una pausa manual (esa
-- la decide la persona y no se revierte sola) — se distinguen con
-- `pausada_por_subtarea`.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_recalcular_bloqueo_subtareas() RETURNS TRIGGER AS $$
DECLARE
  v_tarea_id  BIGINT;
  v_bloqueada BOOLEAN;
  v_tarea     tarea%ROWTYPE;
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
    UPDATE tarea
    SET estatus_antes_pausa = estatus_id,
        estatus_id = 'pausa',
        pausada_por_subtarea = TRUE
    WHERE id = v_tarea_id;
  ELSIF NOT v_bloqueada AND v_tarea.pausada_por_subtarea THEN
    UPDATE tarea
    SET estatus_id = COALESCE(estatus_antes_pausa, 'tareas'),
        estatus_antes_pausa = NULL,
        pausada_por_subtarea = FALSE
    WHERE id = v_tarea_id;
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
-- 13.4 Historial automático — nunca se escribe a mano desde la aplicación.
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
-- 13.5 Evitar dependencias circulares en el Gantt (A depende de B que
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


-- ============================================================================
-- 14. PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 14.1 sp_mover_tarea — equivalente a KanbanRepository.moverTarea: reordena
-- dentro de la columna destino; los triggers de la sección 14 validan WIP,
-- estampan fechas reales y registran historial automáticamente.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_mover_tarea(
  p_tarea_id      BIGINT,
  p_nuevo_estatus VARCHAR(60),
  p_posicion      INTEGER DEFAULT NULL
) LANGUAGE plpgsql AS $$
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
END;
$$;

-- ---------------------------------------------------------------------------
-- 14.2 fn_progreso_tarea — % de actividades terminadas (recursivo, incluye
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
-- 14.3 sp_actualizar_tarea_cascada — al mover la fecha de vencimiento de
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
-- 14.4 sp_crear_tarea_desde_plantilla — clona una TareaPlantilla en una
-- tarea nueva (checklist, etiquetas y miembros sugeridos incluidos). El
-- INSERT en `tarea` ya dispara trg_validar_wip_tarea, así que crear desde
-- plantilla respeta el límite de WIP igual que crear una tarea a mano.
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
    p_workspace_id, p_estatus_id, v_plantilla.titulo_sugerido, v_plantilla.descripcion,
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
-- 14.5 sp_crear_workspace — inserta el área de trabajo + sus 5 columnas
-- estándar, con el mismo título/color/límite que siembra kColumnas
-- (kanban_constants.dart) para cada área nueva.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_crear_workspace(
  p_nombre    VARCHAR(120),
  p_color_hex CHAR(7)
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
  v_workspace_id BIGINT;
BEGIN
  INSERT INTO workspace (nombre, color_hex) VALUES (p_nombre, p_color_hex)
  RETURNING id INTO v_workspace_id;

  INSERT INTO kanban_columna
    (workspace_id, estatus_id, titulo, icono_nombre, color_hex, limite_wip, orden)
  VALUES
    (v_workspace_id, 'tareas',    'TAREAS',     'bookmark_rounded', '#343A40', NULL, 1),
    (v_workspace_id, 'proceso',   'PROCESO',    'bookmark_rounded', '#2196F3', 1,    2),
    (v_workspace_id, 'pausa',     'PAUSA',      'bookmark_rounded', '#FD7E14', NULL, 3),
    (v_workspace_id, 'terminado', 'TERMINADO',  'bookmark_rounded', '#17A2B8', NULL, 4),
    (v_workspace_id, 'revisado',  'REVISADO',   'bookmark_rounded', '#28A745', NULL, 5);

  RETURN v_workspace_id;
END;
$$;
