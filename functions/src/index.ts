/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CLOUD FUNCTIONS - Victoria en Cristo
 * Funciones administrativas que requieren privilegios de admin
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as admin from "firebase-admin";

// Inicializar Firebase Admin ANTES de importar otras funciones
admin.initializeApp();

// Exportar funciones
export {deleteUserData} from "./deleteUserData";

// Muro de Batalla - Funciones de moderación anónima
export {
  createWallPost,
  createWallComment,
  moderateContent,
  reportContent,
  banAbuseHash,
} from "./wallFunctions";
