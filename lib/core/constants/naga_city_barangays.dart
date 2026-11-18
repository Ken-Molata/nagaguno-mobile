// lib/core/constants/naga_city_barangays.dart
//
// NagaGuno operates in Naga City, Camarines Sur specifically (every
// address/barangay field in this app is implicitly within it, never a
// free-text city) -- this is the fixed list of its 27 barangays, used
// wherever a screen asks for one (KYC's address section; registration's
// own barangay field) so the user picks from a real list instead of
// typing it freehand, which is the only way a value here can be
// reliably matched/validated against anything else (e.g. shelf-life or
// delivery-zone logic keyed by barangay name).
const nagaCityBarangays = [
  'Abella',
  'Bagumbayan Norte',
  'Bagumbayan Sur',
  'Balatas',
  'Calauag',
  'Cararayan',
  'Carolina',
  'Concepcion Grande',
  'Concepcion Pequeña',
  'Dayangdang',
  'Del Rosario',
  'Dinaga',
  'Igualdad Interior',
  'Lerma',
  'Liboton',
  'Mabolo',
  'Pacol',
  'Panicuason',
  'Peñafrancia',
  'Sabang',
  'San Felipe',
  'San Francisco',
  'San Isidro',
  'Santa Cruz',
  'Tabuco',
  'Tinago',
  'Triangulo',
];
