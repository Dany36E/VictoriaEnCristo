/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CLOUD FUNCTIONS - Victoria en Cristo
 * Funciones administrativas que requieren privilegios de admin
 * ═══════════════════════════════════════════════════════════════════════════
 */

import {initializeApp} from "firebase-admin/app";

// Inicializar Firebase Admin ANTES de importar otras funciones
initializeApp();

// Exportar funciones
export {deleteUserData} from "./deleteUserData";

// Muro de Batalla - Funciones de moderación anónima
export {
  createWallPost,
  createWallComment,
  moderateContent,
  reportContent,
  blockWallAuthor,
  banAbuseHash,
} from "./wallFunctions";

// Compañero de Batalla - Push notifications y purga
export {
  acceptPartnerInvite,
  onPartnerInviteCreated,
  onBattleMessageCreated,
  purgeOldPartnerInvites,
  rejectPartnerInvite,
  sendBattleMessage,
  sendBattleSos,
  sendPartnerInvite,
} from "./battlePartnerFunctions";

// Liberar compañero (respeta el candado del guardián del Escudo)
export {
  cancelarRetiroCandado,
  liberarCandadosVencidos,
  removeBattlePartner,
} from "./liberarCompanero";

// Rendición de cuentas (opcional): avisos del Escudo y resumen semanal
export {
  enviarResumenSemanal,
  vigilarEscudo,
} from "./rendicionCuentas";

// Modo Estudio Colaborativo - Salas con rotación de traducciones
export {
  createStudyRoom,
  joinStudyRoom,
  leaveStudyRoom,
  rotateStudyVersions,
  startStudyRoomSwapTimer,
  studyRoomAutoSwap,
} from "./studyRoomFunctions";

// Admin claims y limpieza FCM
export {
  setAdminClaim,
  cleanStaleFcmTokens,
  signOutAllDevices,
} from "./adminFunctions";

// Candado del Guardián (remoto) — PIN del compañero para el Escudo de Pureza
export {
  requestGuardianLock,
  setGuardianPin,
  verifyGuardianPin,
  removeGuardianPin,
} from "./guardianFunctions";
