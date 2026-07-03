import flet as ft
import datetime
import requests
import json
import sys
import subprocess
import threading
import time
import base64
from componentes.Rh.abrirprogfirmas import abrir_app_rh
from componentes.animacionlootie.animacioncentrada import GlobalAnimation
from componentes.ayuda.ayuda import open_help
from componentes.kamban.gokamban import open_kamban
from componentes.dashboard.dashboard_permissions import (
    filter_visible_modules,
)
from componentes.reloj.reloj import RelojWidget

class DashboardView:
    def __init__(self, page, go_to):
        print("[DashboardView] Constructor llamado")
        self.page = page
        self.page.assets_dir = "assets"
        self.page.loader = GlobalAnimation(self.page)
        self.go_to = go_to
        self.running = True

        user = getattr(self.page, "session", None)
        if user:
            user = user.get("user")
        if not user:
            user = {}
        
        nombre_completo = user.get("Nombre")
        imagen_url = user.get("imagenURL")

        titulo_size = 42
        subtitulo_size = 18
        if self.page.width < 700:
            titulo_size = 32
            subtitulo_size = 14
        elif self.page.width < 1000:
            titulo_size = 36
            subtitulo_size = 16

        logo_paths = ["/logo sin fondo.png", "logo sin fondo.png"]
        logo = None
        for path in logo_paths:
            try:
                logo = ft.Image(
                    src=path,
                    width=200,
                    height=65,
                    fit="contain"
                )
                print(f"[DEBUG] ✓ Logo cargado desde: {path}")
                break
            except Exception:
                continue
        if logo is None:
            logo = ft.Text(
                "GRUPO PM",
                size=24,
                weight=ft.FontWeight.BOLD,
                color="#1565C0"
            )

        self.fecha_hora_text = ft.Text(
            self.get_datetime_str(), size=14, color="#666666"
        )

        # Widget de reloj (abajo a la izquierda del dashboard)
        self.reloj_widget = RelojWidget().get_widget()

        def is_valid_image_url(url):
            if not url:
                return False
            valid_ext = (".jpg", ".jpeg", ".png", ".gif", ".webp")
            return url.startswith("http") and url.lower().endswith(valid_ext)
        
        perfil_icon = user.get("imagenURL") 
        clave_perfil = str(user.get("ClavePerfil") or "").strip()

        self.modules = [
            {"label": "Mi perfil", "icon": ft.Icons.PERSON, "route": "perfil", "avatar": perfil_icon},
            {"label": "Vigilancia In/Out", "icon": ft.Icons.VIDEO_CAMERA_FRONT, "route": "vigilancia"},
            {"label": "Kanban PM", "icon": ft.Icons.VIEW_KANBAN, "route": "kanban"},
            {"label": "IT Management", "icon": ft.Icons.DEVICES_OTHER, "route": "it"},
            {"label": "Tickets de Soporte", "icon": ft.Icons.SUPPORT_AGENT, "route": "tickets_initial"},
            {
                "label": "RH",
                "icon": ft.Icons.BADGE,
                "route": "rh",
                "description": "Gestión de Recursos Humanos, empleados y nómina",
                "color": "#1976D2"
            },
            {
                "label": "Centro de Ayuda",
                "icon": ft.Icons.HELP,
                "route": "ayuda",
                "description": "Accede a la documentación y soporte",
                "color": "#9C27B0"},
            {
                "label": "Bitácora Pintura",
                "icon": ft.Icons.BRUSH,
                "route": "bitacora_dashboard",
                "description": "Registro de actividades de pintura",
                "color": "#E64A19"
            }
        ]

        visible_modules = filter_visible_modules(self.modules, clave_perfil)
        if not clave_perfil:
            print("[DashboardView] Clave_perfil no disponible, mostrando módulos por defecto")

        icons_controls = []
        for mod in visible_modules:
            label = mod["label"]
            icon = mod["icon"]
            route = mod["route"]
            avatar = mod.get("avatar", None)
            icons_controls.append(
                self.create_icon_button(label, icon, avatar, route)
            )

        self.Icons_row = ft.ResponsiveRow(
            icons_controls,
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=28,
            run_spacing=28,
        )

        # Encabezado superior
        header_container = ft.Container(
            content=ft.Row([
                ft.Container(content=logo, padding=8),
                ft.Row([
                    ft.Text("", expand=True),
                ], alignment=ft.MainAxisAlignment.END),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            bgcolor="#FFFFFF",
            padding=ft.padding.symmetric(horizontal=24, vertical=16),
            shadow=ft.BoxShadow(
                blur_radius=8,
                color="#00000010",
                offset=ft.Offset(0, 2),
            ),
        )

        # Contenido central (bienvenida + íconos)
        body_container = ft.Container(
            expand=True,
            padding=ft.padding.symmetric(horizontal=20, vertical=15),
            content=ft.Column(
                [
                    # 🔹 TOP — Título y nombre
                    ft.Column(
                        [
                            ft.Text(
                                "BIENVENIDO",
                                size=titulo_size,
                                weight=ft.FontWeight.BOLD,
                                color="#000000",
                                text_align=ft.TextAlign.CENTER,
                            ),

                            ft.Text(
                                nombre_completo.upper(),
                                size=subtitulo_size,
                                color="#666666",
                                text_align=ft.TextAlign.CENTER,
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    ),

                    # 🔹 CENTRO — Iconos (se expande y centra)
                    ft.Container(
                        expand=True,
                        alignment=ft.alignment.center,
                        content=self.Icons_row,
                        padding=ft.padding.symmetric(vertical=10),
                    ),

                    # 🔹 BOTTOM — Fecha
                    ft.Container(
                        alignment=ft.alignment.center,
                        padding=ft.padding.only(top=12, bottom=10),
                        content=self.fecha_hora_text,
                    ),
                ],
                expand=True,
                spacing=24,
                alignment=ft.MainAxisAlignment.CENTER,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            ),
        )
        
        scroll_mode = (
            ft.ScrollMode.AUTO
            if self.page.width < 700
            else None
        )


        # Vista final: header arriba, contenido al centro y reloj pegado abajo a la izquierda
        self.view = ft.Column(
            [
                header_container,
                body_container,
            ],
            spacing=0,
            expand=True,
            scroll=scroll_mode,
        )

        # Iniciar hilo de actualización de fecha y hora
        self.start_datetime_update()
        
        
    
    def create_icon_button(self, label, icon, avatar_path, route):
        """Crea un icono circular con hover (manteniendo tu experiencia pero usando ft.icons)"""
        # si avatar_path es una URL o ruta local, lo muestro como imagen circular
        if isinstance(avatar_path, (bytes, bytearray)):
            base64_src = base64.b64encode(avatar_path).decode()
            inner = ft.Image(src_base64=base64_src, width=56, height=56, fit="cover")
            circle = ft.Container(
                content=inner,
                width=90,
                height=90,
                bgcolor="#f0f0f0",
                border_radius=40,
                animate=ft.Animation(200, "easeOut"),
                animate_scale=ft.Animation(200, "easeOut"),
                shadow=ft.BoxShadow(blur_radius=2, color="#00000012"),
            )
        elif avatar_path and (avatar_path.startswith("http") or avatar_path.endswith((".png", ".jpg", ".jpeg", ".webp", ".gif"))):
            inner = ft.Image(src=avatar_path, width=56, height=56, fit="cover")
            circle = ft.Container(
                content=inner,
                width=80,
                height=80,
                bgcolor="#f0f0f0",
                border_radius=40,
                animate=ft.Animation(200, "easeOut"),
                animate_scale=ft.Animation(200, "easeOut"),
                shadow=ft.BoxShadow(blur_radius=2, color="#00000012"),
            )
        else:
            inner = ft.Icon(icon, size=45, color="#ffffff")
            # color base por label (simple heurística para variedad)
            color_map = {
                "Mi perfil": "#26A69A",
                "Administrar Usuarios": "#42A5F5",
                "Vigilancia In/Out": "#7E57C2",
                "Kanban PM": "#FFA726",
                "IT Management": "#5C6BC0",
                "Tickets de Soporte": "#EF5350",
                "RH": "#29B6F6",
                "Ayuda": "#9C27B0",
                "Bitácora Pintura": "#0FE64C"
            }
            bgcolor = color_map.get(label, "#607D8B")
            circle = ft.Container(
                content=inner,
                width=90,
                height=90,
                bgcolor=bgcolor,
                border_radius=40,
                animate_scale=ft.Animation(200, "easeOut"),
                shadow=ft.BoxShadow(blur_radius=2, color="#00000012"),
            )
            
        def on_hover(e: ft.HoverEvent):
            if e.data == "true":
                circle.scale = 1.08

                if isinstance(inner, ft.Icon):
                    circle.bgcolor = "#1565C0"

            else:
                circle.scale = 1.0

                if isinstance(inner, ft.Icon):
                    circle.bgcolor = bgcolor

            if circle.page:   # 👈 evita update cuando ya no está en pantalla
                circle.update()


        def on_tap(e):
            if route == "perfil":
                self.go_to("perfil")

            elif route == "configuracion":
                self.go_to("configuracion")

            elif route == "vigilancia":
                self.go_to("vigilancia")

            elif route == "kanban":
                open_kamban(self.page)
                print(f"{label} clicado - Abriendo Kanban PM en el navegador")

            elif route == "it":
                self.go_to("it")

            elif route == "tickets_initial":
                self.go_to("tickets_initial")

            elif route == "solicitar_ticket":
                self.go_to("solicitar_ticket")

            elif route == "jefes_departamento":
                self.go_to("jefes_departamento")

            elif route == "rh":
                abrir_app_rh(self.page)
                print(f"{label} clicado - Abriendo aplicación RH PM.exe")

            elif route == "ayuda":
                open_help(self.page)
                print(f"{label} clicado - Abriendo ayuda en el navegador")

            elif route == "bitacora_dashboard":
                self.go_to("bitacora_dashboard")
                print(f"{label} clicado - Navegando a Bitácora de Pintura")

            else:
                print(f"{label} clicado")


        gesture_circle = ft.GestureDetector(
            content=circle,
            on_hover=on_hover,
            on_tap=on_tap,
        )

        return ft.Container(
        content=ft.Column(
            [
                gesture_circle,
                ft.Container(height=4),
                ft.Text(label, size=14, text_align=ft.TextAlign.CENTER),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        ),
        col={"xs": 6, "sm": 4, "md": 3, "lg": 2, "xl": 1},
        alignment=ft.alignment.center,
    )
        
    

    def get_datetime_str(self):
        now = datetime.datetime.now()
        return now.strftime("%d de %B de %Y, %I:%M %p")

    def start_datetime_update(self):
        """Actualizar fecha y hora cada minuto (igual que original)"""
        def update_clock():
            while self.running:
                self.fecha_hora_text.value = self.get_datetime_str()
                try:
                    self.page.update()
                except Exception:
                    pass
                time.sleep(60)

        threading.Thread(target=update_clock, daemon=True).start()

    def cleanup(self):
        """Detener hilos cuando se abandona la vista"""
        self.running = False



class AdminUsuariosView:
    """Vista principal de administración de usuarios"""

    def __init__(self, page, go_to):
        self.page = page
        self.go_to = go_to

        try:
            user = self.page.session["user"] if hasattr(self.page, "session") and hasattr(self.page.session, "__getitem__") and "user" in self.page.session else {}
        except Exception:
            user = {}
        rol = user.get("rol", "").lower()

        if rol not in ["admin", "administrador", "superadmin"]:
            self.view = ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.LOCK, size=64, color="#E74C3C"),
                    ft.Container(height=20),
                    ft.Text("Acceso denegado", size=24, weight=ft.FontWeight.BOLD),
                    ft.Text("No tienes permisos para acceder a esta sección", size=14, color="#666666"),
                    ft.Container(height=30),
                    ft.ElevatedButton(
                        "Volver al inicio",
                        icon=ft.Icons.HOME,
                        on_click=lambda e: self.go_to("dashboard"),
                        style=ft.ButtonStyle(bgcolor="#1976D2", color="#FFFFFF")
                    )
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                expand=True,
                # alignment eliminado para compatibilidad
            )
            return

        header = ft.Container(
            content=ft.Row([
                ft.IconButton(
                    icon=ft.Icons.ARROW_BACK,
                    on_click=lambda e: self.go_to("dashboard"),
                    tooltip="Volver al inicio"
                ),
                ft.Text(
                    "Administración de Usuarios",
                    size=24,
                    weight=ft.FontWeight.BOLD,
                    color="#1976D2"
                ),
            ]),
            bgcolor="#FFFFFF",
            padding=20,
            shadow=ft.BoxShadow(blur_radius=4, color="#00000010"),
        )

        options = [
            {
                "title": "Listar Usuarios",
                "icon": ft.Icons.LIST,
                "description": "Ver todos los usuarios registrados",
                "action": "listar",
                "color": "#3498DB"
            },
            {
                "title": "Agregar Usuario",
                "icon": ft.Icons.PERSON_ADD,
                "description": "Registrar un nuevo usuario",
                "action": "agregar",
                "color": "#2ECC71"
            },
            {
                "title": "Modificar Usuario",
                "icon": ft.Icons.EDIT,
                "description": "Editar información de usuarios",
                "action": "modificar",
                "color": "#F39C12"
            },
            {
                "title": "Eliminar Usuario",
                "icon": ft.Icons.DELETE,
                "description": "Eliminar usuarios del sistema",
                "action": "eliminar",
                "color": "#E74C3C"
            },
            {
                "title": "Roles y Permisos",
                "icon": ft.Icons.ADMIN_PANEL_SETTINGS,
                "description": "Gestionar roles de usuarios",
                "action": "roles",
                "color": "#9B59B6"
            },
            {
                "title": "Reportes",
                "icon": ft.Icons.ANALYTICS,
                "description": "Estadísticas y reportes",
                "action": "reportes",
                "color": "#1ABC9C"
            },
        ]

        grid = ft.GridView(
            expand=True,
            runs_count=3,
            max_extent=250,
            child_aspect_ratio=1.0,
            spacing=20,
            run_spacing=20,
            padding=20,
        )

        for opt in options:
            card = self.create_option_card(
                opt["title"],
                opt["icon"],
                opt["description"],
                opt["action"],
                opt["color"]
            )
            grid.controls.append(card)

        self.view = ft.Container(
            content=ft.Column([
                header,
                ft.Container(
                    content=grid,
                    expand=True,
                    bgcolor="#F5F6FA"
                )
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            expand=True
            # alignment eliminado para compatibilidad
        )

    def create_option_card(self, title, icon, description, action, color):
        """Crea una tarjeta de opción (igual funcionalidad; pequeño pulido visual)"""
        return ft.Container(
            content=ft.Column([
                ft.Icon(icon, size=48, color=color),
                ft.Container(height=10),
                ft.Text(
                    title,
                    size=16,
                    weight=ft.FontWeight.BOLD,
                    text_align=ft.TextAlign.CENTER
                ),
                ft.Container(height=5),
                ft.Text(
                    description,
                    size=12,
                    color="#666666",
                    text_align=ft.TextAlign.CENTER
                ),
            ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
            ),
            bgcolor="#FFFFFF",
            border_radius=12,
            padding=20,
            shadow=ft.BoxShadow(
                blur_radius=8,
                color="#00000010",
                offset=ft.Offset(0, 2)
            ),
            on_click=lambda e, a=action: self.handle_action(a),
            ink=True,
            animate=ft.Animation(200, "easeOut"),
        )

    def handle_action(self, action):
        """Maneja las acciones de las tarjetas (misma lógica)"""
        if action == "listar":
            self.go_to("admin_listar_usuarios")
        elif action == "agregar":
            self.go_to("admin_agregar_usuario")
        elif action == "modificar":
            self.go_to("admin_modificar_usuario")
        elif action == "eliminar":
            self.go_to("admin_eliminar_usuario")
        elif action == "roles":
            self.show_info("Módulo de roles en desarrollo")
        elif action == "reportes":
            self.show_info("Módulo de reportes en desarrollo")

    def show_info(self, message):
        """Muestra un diálogo informativo"""
        def close_dialog(e):
            dialog.open = False
            self.page.update()

        dialog = ft.AlertDialog(
            title=ft.Text("Información"),
            content=ft.Text(message),
            actions=[ft.TextButton("OK", on_click=close_dialog)]
        )
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()



