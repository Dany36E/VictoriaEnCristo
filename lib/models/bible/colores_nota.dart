/// Colores con nombre de las Notas (resaltado y texto), en ARGB para que
/// los compartan la pantalla y el PDF.
library;

/// Fondo translúcido del resaltado.
const Map<String, int> coloresResaltado = {
  'amarillo': 0x80FFE066,
  'verde': 0x739BE58A,
  'azul': 0x738FD3FF,
  'rosa': 0x73FF9EC7,
  'naranja': 0x73FFB86B,
};

/// Color de texto sobre fondo claro.
const Map<String, int> coloresTextoClaro = {
  'terracota': 0xFFC8553D,
  'azul': 0xFF3D6890,
  'verde': 0xFF2F7F7A,
  'mostaza': 0xFFB07D1F,
  'morado': 0xFF7E57C2,
  'gris': 0xFF8A7A64,
};

/// Color de texto sobre fondo oscuro (más luminoso para que se lea).
const Map<String, int> coloresTextoOscuro = {
  'terracota': 0xFFF08A6E,
  'azul': 0xFF8DB8E3,
  'verde': 0xFF7CCFC6,
  'mostaza': 0xFFF2C66B,
  'morado': 0xFFB9A2F0,
  'gris': 0xFFB7AE9F,
};

const Map<String, String> nombresColoresNota = {
  'amarillo': 'Amarillo',
  'verde': 'Verde',
  'azul': 'Azul',
  'rosa': 'Rosa',
  'naranja': 'Naranja',
  'terracota': 'Terracota',
  'mostaza': 'Mostaza',
  'morado': 'Morado',
  'gris': 'Gris',
};
