import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Manejo de la Imagen de Perfil
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Controladores para la edición de información
  bool _isEditing = false;
  final _nameController = TextEditingController(text: 'Ing. Alejandro Martínez');
  final _roleController = TextEditingController(text: 'Project Manager Senior');
  final _emailController = TextEditingController(text: 'a.martinez@empresa.com');
  final _deptController = TextEditingController(text: 'Oficina de Gestión de Proyectos (PMO)');

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  // Función para abrir la cámara / selector de archivos
  Future<void> _pickImage() async {
    try {
      // En Web abre el explorador de archivos. En móvil, usa la cámara directamente.
      final XFile? pickedFile = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada correctamente')),
        );
      }
    } catch (e) {
      debugPrint('Error al capturar imagen: $e');
    }
  }

  // Widget dinámico para renderizar la imagen cargada
  Widget _buildAvatarImage() {
    if (_imageFile != null) {
      if (kIsWeb) {
        return ClipOval(
          child: Image.network(
            _imageFile!.path,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      } else {
        return ClipOval(
          child: Image.file(
            File(_imageFile!.path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    
    // Avatar por defecto si no hay foto seleccionada
    return const Icon(
      Icons.person_rounded,
      size: 50,
      color: Color(0xFF3182CE),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, 
        leading: null,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A202C), fontSize: 20),
        ),
        titleSpacing: kIsWeb ? 24 : NavigationToolbar.kMiddleSpacing,
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TARJETA PRINCIPAL: AVATAR Y NOMBRES
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFEBF8FF),
                              child: _buildAvatarImage(),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: _pickImage, // Al darle click abre el selector de imagen
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3182CE),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Campos de texto dinámicos según modo edición
                        _isEditing
                            ? TextField(
                                controller: _nameController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                decoration: const InputDecoration(hintText: 'Nombre Completo'),
                              )
                            : Text(
                                _nameController.text,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A202C)),
                                textAlign: TextAlign.center,
                              ),
                        const SizedBox(height: 6),
                        _isEditing
                            ? TextField(
                                controller: _roleController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(hintText: 'Puesto o Rol'),
                              )
                            : Text(
                                _roleController.text,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF718096)),
                                textAlign: TextAlign.center,
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // SECCIÓN: DATOS DE CONTACTO CORPORATIVOS
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    'Información Corporativa',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF718096), letterSpacing: 0.5),
                  ),
                ),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email_outlined, color: Color(0xFF4A5568)),
                          title: const Text('Correo Electrónico', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
                          subtitle: _isEditing
                              ? TextField(controller: _emailController)
                              : Text(_emailController.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                        ),
                        const Divider(height: 16, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.business_center_outlined, color: Color(0xFF4A5568)),
                          title: const Text('Departamento / Área', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
                          subtitle: _isEditing
                              ? TextField(controller: _deptController)
                              : Text(_deptController.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // BOTÓN DE ACCIÓN: INTERCAMBIA ENTRE "EDITAR" Y "GUARDAR CAMBIOS"
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_isEditing) {
                        // Acción al presionar GUARDAR
                        _isEditing = false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cambios guardados con éxito'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        // Acción al presionar EDITAR
                        _isEditing = true;
                      }
                    });
                  },
                  icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded, size: 18),
                  label: Text(_isEditing ? 'Guardar Cambios' : 'Editar Información'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? const Color(0xFF38A169) : const Color(0xFF3182CE), // Cambia a verde en guardar
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}